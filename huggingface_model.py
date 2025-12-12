"""
Hugging Face model integration
"""
from base_model import AIModel
from huggingface_hub import InferenceClient


class HuggingFaceModel(AIModel):
    """Hugging Face model integration"""
    
    def __init__(self, api_key: str, model_name: str = "meta-llama/Llama-2-7b-chat-hf"):
        """
        Initialize Hugging Face model
        
        Args:
            api_key: Hugging Face API key
            model_name: Model to use (default: meta-llama/Llama-2-7b-chat-hf)
        """
        super().__init__(api_key)
        self.model_name = model_name
        self.client = None
        if self.is_available():
            self.client = InferenceClient(token=api_key)
    
    def generate_response(self, prompt: str, **kwargs) -> str:
        """
        Generate response using Hugging Face API
        
        Args:
            prompt: Input prompt
            **kwargs: Additional parameters (temperature, max_tokens, etc.)
            
        Returns:
            str: Generated response
        """
        if not self.is_available():
            return "Error: Hugging Face API key not configured"
        
        try:
            response = self.client.text_generation(
                prompt,
                model=self.model_name,
                max_new_tokens=kwargs.get("max_tokens", 1000),
                temperature=kwargs.get("temperature", 0.7)
            )
            return response
        except Exception as e:
            return f"Error generating response from Hugging Face: {str(e)}"
    
    def get_model_name(self) -> str:
        """Get model name"""
        return f"Hugging Face {self.model_name}"
