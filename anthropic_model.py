"""
Anthropic Claude model integration
"""
from base_model import AIModel
from anthropic import Anthropic


class AnthropicModel(AIModel):
    """Anthropic Claude model integration"""
    
    def __init__(self, api_key: str, model_name: str = "claude-3-haiku-20240307"):
        """
        Initialize Anthropic model
        
        Args:
            api_key: Anthropic API key
            model_name: Model to use (default: claude-3-haiku-20240307)
        """
        super().__init__(api_key)
        self.model_name = model_name
        self.client = None
        if self.is_available():
            self.client = Anthropic(api_key=api_key)
    
    def generate_response(self, prompt: str, **kwargs) -> str:
        """
        Generate response using Anthropic API
        
        Args:
            prompt: Input prompt
            **kwargs: Additional parameters (temperature, max_tokens, etc.)
            
        Returns:
            str: Generated response
        """
        if not self.is_available():
            return "Error: Anthropic API key not configured"
        
        try:
            message = self.client.messages.create(
                model=self.model_name,
                max_tokens=kwargs.get("max_tokens", 1000),
                temperature=kwargs.get("temperature", 0.7),
                messages=[
                    {"role": "user", "content": prompt}
                ]
            )
            return message.content[0].text
        except Exception as e:
            return f"Error generating response from Anthropic: {str(e)}"
    
    def get_model_name(self) -> str:
        """Get model name"""
        return f"Anthropic {self.model_name}"
