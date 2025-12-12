"""
Cohere model integration
"""
from base_model import AIModel
import cohere


class CohereModel(AIModel):
    """Cohere model integration"""
    
    def __init__(self, api_key: str, model_name: str = "command"):
        """
        Initialize Cohere model
        
        Args:
            api_key: Cohere API key
            model_name: Model to use (default: command)
        """
        super().__init__(api_key)
        self.model_name = model_name
        self.client = None
        if self.is_available():
            self.client = cohere.Client(api_key)
    
    def generate_response(self, prompt: str, **kwargs) -> str:
        """
        Generate response using Cohere API
        
        Args:
            prompt: Input prompt
            **kwargs: Additional parameters (temperature, max_tokens, etc.)
            
        Returns:
            str: Generated response
        """
        if not self.is_available():
            return "Error: Cohere API key not configured"
        
        try:
            response = self.client.chat(
                message=prompt,
                model=self.model_name,
                temperature=kwargs.get("temperature", 0.7),
                max_tokens=kwargs.get("max_tokens", 1000)
            )
            return response.text
        except Exception as e:
            return f"Error generating response from Cohere: {str(e)}"
    
    def get_model_name(self) -> str:
        """Get model name"""
        return f"Cohere {self.model_name}"
