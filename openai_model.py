"""
OpenAI model integration
"""
from base_model import AIModel
from openai import OpenAI


class OpenAIModel(AIModel):
    """OpenAI GPT model integration"""
    
    def __init__(self, api_key: str, model_name: str = "gpt-3.5-turbo"):
        """
        Initialize OpenAI model
        
        Args:
            api_key: OpenAI API key
            model_name: Model to use (default: gpt-3.5-turbo)
        """
        super().__init__(api_key)
        self.model_name = model_name
        self.client = None
        if self.is_available():
            self.client = OpenAI(api_key=api_key)
    
    def generate_response(self, prompt: str, **kwargs) -> str:
        """
        Generate response using OpenAI API
        
        Args:
            prompt: Input prompt
            **kwargs: Additional parameters (temperature, max_tokens, etc.)
            
        Returns:
            str: Generated response
        
        Note:
            max_tokens parameter works with both older and newer OpenAI models.
            For chat completions, it limits the total tokens in the response.
        """
        if not self.is_available():
            return "Error: OpenAI API key not configured"
        
        try:
            response = self.client.chat.completions.create(
                model=self.model_name,
                messages=[
                    {"role": "user", "content": prompt}
                ],
                temperature=kwargs.get("temperature", 0.7),
                max_tokens=kwargs.get("max_tokens", 1000)
            )
            return response.choices[0].message.content
        except Exception as e:
            return f"Error generating response from OpenAI: {str(e)}"
    
    def get_model_name(self) -> str:
        """Get model name"""
        return f"OpenAI {self.model_name}"
