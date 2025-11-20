"""
LLM Analysis module for topic refinement using OpenAI
"""
import json
import time
from typing import List, Dict, Optional
from openai import OpenAI
from config import OPENAI_API_KEY, OPENAI_MODEL, OPENAI_MODEL_FALLBACK

class TopicAnalyzer:
    def __init__(self, model: str = OPENAI_MODEL):
        """Initialize OpenAI client"""
        if not OPENAI_API_KEY:
            raise ValueError("OPENAI_API_KEY not set in environment variables")

        self.client = OpenAI(api_key=OPENAI_API_KEY)
        self.model = model
        self.total_tokens = 0
        self.total_cost = 0.0

    def analyze_single_topic(self, topic_data: Dict, themes: List[Dict]) -> Dict:
        """Analyze a single topic with LLM"""

        # Build the prompt
        prompt = self._build_analysis_prompt(topic_data, themes)

        try:
            # Call OpenAI
            response = self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {
                        "role": "system",
                        "content": "You are an expert OSINT analyst specializing in social media monitoring and narrative analysis. You help clean up and categorize machine-discovered topics from social media data."
                    },
                    {
                        "role": "user",
                        "content": prompt
                    }
                ],
                response_format={"type": "json_object"},
                temperature=0.3,  # Lower temperature for consistent categorization
                max_tokens=1000
            )

            # Parse response
            raw_content = response.choices[0].message.content

            try:
                result = json.loads(raw_content)
            except json.JSONDecodeError as e:
                print(f"    ERROR: Failed to parse JSON response: {e}")
                return self._get_fallback_response(topic_data)

            # Track usage
            tokens_used = response.usage.total_tokens
            self.total_tokens += tokens_used

            # Estimate cost (gpt-4o pricing as of late 2024)
            # Input: $2.50 per 1M tokens, Output: $10.00 per 1M tokens
            input_cost = (response.usage.prompt_tokens / 1_000_000) * 2.50
            output_cost = (response.usage.completion_tokens / 1_000_000) * 10.00
            cost = input_cost + output_cost
            self.total_cost += cost

            # Add metadata
            result['processing_metadata'] = {
                'model': self.model,
                'tokens_used': tokens_used,
                'cost_usd': round(cost, 4),
                'timestamp': time.strftime('%Y-%m-%d %H:%M:%S')
            }

            return result

        except Exception as e:
            print(f"Error analyzing topic {topic_data.get('topic_id')}: {e}")
            return self._get_fallback_response(topic_data)

    def analyze_batch(self, topics: List[Dict], themes: List[Dict]) -> List[Dict]:
        """Analyze multiple topics in a batch for efficiency"""

        prompt = self._build_batch_prompt(topics, themes)

        try:
            response = self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {
                        "role": "system",
                        "content": "You are an expert OSINT analyst. Analyze these social media topics and provide structured categorization and insights."
                    },
                    {
                        "role": "user",
                        "content": prompt
                    }
                ],
                response_format={"type": "json_object"},
                temperature=0.3,
                max_tokens=4000
            )

            # Parse batch response
            result = json.loads(response.choices[0].message.content)

            # Track usage
            tokens_used = response.usage.total_tokens
            self.total_tokens += tokens_used

            # Calculate cost
            input_cost = (response.usage.prompt_tokens / 1_000_000) * 2.50
            output_cost = (response.usage.completion_tokens / 1_000_000) * 10.00
            cost = input_cost + output_cost
            self.total_cost += cost

            # Handle both single topic list and 'topics' wrapper
            if 'topics' in result:
                refined_topics = result.get('topics', [])
            elif isinstance(result, list):
                refined_topics = result
            elif isinstance(result, dict) and 'id' in result:
                # Single topic response wrapped as dict
                refined_topics = [result]
            else:
                refined_topics = []

            # Fix topic_id field and add metadata
            for topic in refined_topics:
                # Map 'id' to 'topic_id' if needed
                if 'id' in topic and 'topic_id' not in topic:
                    topic['topic_id'] = topic['id']

                topic['processing_metadata'] = {
                    'model': self.model,
                    'batch_size': len(topics),
                    'tokens_per_topic': tokens_used // len(topics) if len(topics) > 0 else tokens_used,
                    'cost_per_topic': round(cost / len(topics), 4) if len(topics) > 0 else cost,
                    'timestamp': time.strftime('%Y-%m-%d %H:%M:%S')
                }

            return refined_topics

        except Exception as e:
            print(f"Error in batch analysis: {e}")
            # Fall back to individual analysis
            return [self.analyze_single_topic(topic, themes) for topic in topics]

    def _build_analysis_prompt(self, topic_data: Dict, themes: List[Dict]) -> str:
        """Build prompt for single topic analysis"""

        # Prepare theme list for context
        theme_list = "\n".join([
            f"- Theme {t['theme_id']}: {t['theme_name']} - {t.get('description', 'N/A')}"
            for t in themes
        ])

        # Extract top keywords (limit to avoid token overflow)
        keywords = topic_data.get('top_words', [])[:20]
        if isinstance(keywords, str):
            keywords = json.loads(keywords) if keywords else []

        # Get sample texts
        samples = topic_data.get('sample_texts', [])[:5]

        prompt = f"""Analyze this machine-discovered topic from social media monitoring.

**PROJECT CONTEXT: Sudan-UAE Conflict Monitoring**
We monitor UAE's involvement in Sudan conflict, including:
- RSF support and terrorism links
- Gold/arms trade connections
- Boycott campaigns against UAE
- Sportswashing (e.g., Manchester City ownership)
- Humanitarian crisis documentation

**Topic Information:**
- Topic ID: {topic_data['topic_id']}
- Current Name: {topic_data['topic_name']}
- Current Label: {topic_data.get('topic_label', 'N/A')}
- Size: {topic_data['topic_size']} tweets
- Keywords: {', '.join(keywords[:15])}

**Sample Tweets (if available):**
{chr(10).join([f"- {s}" for s in samples[:3]]) if samples else "No samples available"}

**Existing Monitoring Themes:**
{theme_list}

**Please provide a JSON response with:**
{{
  "topic_id": {topic_data['topic_id']},
  "refined_name": "Clean, descriptive name (max 5 words)",
  "refined_label": "Clear one-sentence description of what this topic represents",
  "category": "Choose: Humanitarian Crisis | Political Campaign | Social Movement | Economic | Environmental | Health | Technology | Sports/Entertainment | Spam/Noise",
  "subcategory": "More specific sub-category",
  "aligned_theme_ids": [list of matching theme IDs or empty array],
  "suggested_new_theme": "If no good match, suggest new theme name or null",
  "alignment_confidence": 0.0-1.0,
  "clean_keywords": ["list", "of", "10", "clean", "meaningful", "keywords"],
  "entities": {{
    "locations": ["extracted", "locations"],
    "organizations": ["extracted", "orgs"],
    "people": ["extracted", "people"],
    "events": ["extracted", "events"]
  }},
  "overall_sentiment": "positive | negative | neutral | mixed",
  "stance": {{
    "supporting": ["what people support"],
    "opposing": ["what people oppose"]
  }},
  "quality_score": 0.0-1.0,  // Is this a coherent topic or spam?
  "relevance_to_project": 0.0-1.0,  // How valuable for OSINT monitoring?
  "noise_level": "low | medium | high",
  "monitoring_priority": "high | medium | low | ignore",
  "recommended_actions": [
    {{
      "action_type": "add_query | modify_query | add_user | track_hashtag | alert_setup | ignore",
      "query": "Specific Twitter search query or username",
      "frequency": "daily | weekly | hourly | real-time",
      "reason": "Why this action is recommended"
    }}
  ],
  "llm_model": "{self.model}"
}}

Focus on the Sudan/UAE context if relevant. Identify humanitarian crises, political movements, and potential disinformation campaigns.

For recommended_actions, provide SPECIFIC, EXECUTABLE actions:
- add_query: Provide exact Twitter search query (e.g., "Manchester City Sudan" OR "ManCity UAE boycott")
- add_user: Specific Twitter username to monitor (e.g., "@username")
- track_hashtag: Specific hashtag to follow (e.g., "#BoycottManCity")
- alert_setup: Specific keywords for alerts (e.g., "ManCity AND (Sudan OR RSF)")
- ignore: If topic is spam/irrelevant

DO NOT suggest vague actions like "monitor trends" or "engage stakeholders"."""

        return prompt

    def _build_batch_prompt(self, topics: List[Dict], themes: List[Dict]) -> str:
        """Build prompt for batch analysis"""

        theme_list = "\n".join([
            f"- Theme {t['theme_id']}: {t['theme_name']}"
            for t in themes
        ])

        topics_info = []
        for t in topics[:10]:  # Limit to 10 topics per batch
            keywords = t.get('top_words', [])[:10]
            if isinstance(keywords, str):
                keywords = json.loads(keywords) if keywords else []

            topics_info.append(f"""
Topic {t['topic_id']}:
- Name: {t['topic_name']}
- Size: {t['topic_size']} tweets
- Keywords: {', '.join(keywords[:8])}
""")

        prompt = f"""Analyze these machine-discovered topics from social media:

**Topics to Analyze:**
{chr(10).join(topics_info)}

**Existing Monitoring Themes:**
{theme_list}

**CRITICAL: Return ONLY a valid JSON object with this EXACT structure:**
{{
  "topics": [
    {{
      "topic_id": {topics[0]['topic_id']},
      "refined_name": "Clean 5-word name",
      "refined_label": "One sentence description",
      "category": "Humanitarian Crisis | Political Campaign | Social Movement | Economic | Environmental | Health | Technology | Sports/Entertainment | Spam/Noise",
      "subcategory": "More specific category",
      "aligned_theme_ids": [1, 2],
      "suggested_new_theme": "Name or null",
      "alignment_confidence": 0.85,
      "clean_keywords": ["keyword1", "keyword2"],
      "entities": {{
        "locations": ["location1"],
        "organizations": ["org1"],
        "people": ["person1"],
        "events": ["event1"]
      }},
      "overall_sentiment": "positive | negative | neutral | mixed",
      "stance": {{
        "supporting": ["what they support"],
        "opposing": ["what they oppose"]
      }},
      "quality_score": 0.75,
      "relevance_to_project": 0.80,
      "noise_level": "low | medium | high",
      "monitoring_priority": "high | medium | low | ignore",
      "recommended_actions": [
        {{
          "action_type": "add_query | add_user | track_hashtag | alert_setup",
          "query": "Exact search query or @username or #hashtag",
          "frequency": "daily | hourly | real-time",
          "reason": "Brief explanation"
        }}
      ],
      "llm_model": "{self.model}"
    }}
    // ... repeat for each topic
  ]
}}

IMPORTANT:
- Use "topic_id" not "id"
- Include ALL topics in the response
- Each topic MUST have ALL the fields shown above
- topic_id values: {', '.join([str(t['topic_id']) for t in topics[:10]])}"""

        return prompt

    def _get_fallback_response(self, topic_data: Dict) -> Dict:
        """Generate a basic response without LLM if API fails"""

        # Clean up the topic name
        name_parts = topic_data['topic_name'].replace('_', ' ').split()[:5]
        clean_name = ' '.join(name_parts)

        return {
            'topic_id': topic_data['topic_id'],
            'refined_name': clean_name,
            'refined_label': f"Topic about {clean_name}",
            'category': 'Uncategorized',
            'subcategory': None,
            'aligned_theme_ids': [],
            'suggested_new_theme': None,
            'alignment_confidence': 0.0,
            'clean_keywords': topic_data.get('top_words', [])[:10],
            'entities': {},
            'overall_sentiment': 'neutral',
            'stance': {},
            'quality_score': 0.5,
            'relevance_to_project': 0.5,
            'noise_level': 'medium',
            'monitoring_priority': 'low',
            'recommended_actions': ['Manual review required'],
            'llm_model': 'fallback',
            'processing_metadata': {
                'error': 'LLM analysis failed, using fallback',
                'timestamp': time.strftime('%Y-%m-%d %H:%M:%S')
            }
        }

    def get_usage_stats(self) -> Dict:
        """Get token usage and cost statistics"""
        return {
            'total_tokens': self.total_tokens,
            'total_cost_usd': round(self.total_cost, 2),
            'model': self.model
        }