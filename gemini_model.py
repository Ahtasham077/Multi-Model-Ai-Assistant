"""
Google Gemini model integration
"""
from base_model import AIModel
import google.generativeai as genai


class GeminiModel(AIModel):
    """Google Gemini model integration"""
    
    def __init__(self, api_key: str, model_name: str = "gemini-pro"):
        """
        Initialize Gemini model
        
        Args:
            api_key: Google API key
            model_name: Model to use (default: gemini-pro)
        """
        super().__init__(api_key)
        self.model_name = model_name
        self.model = None
        if self.is_available():
            genai.configure(api_key=api_key)
            self.model = genai.GenerativeModel(model_name)
    
    def generate_response(self, prompt: str, **kwargs) -> str:
        """
        Generate response using Google Gemini API
        
        Args:
            prompt: Input prompt
            **kwargs: Additional parameters
            
        Returns:
            str: Generated response
        
        Note:
            The max_tokens parameter is mapped to max_output_tokens for Gemini API compatibility.
        """
        if not self.is_available():
            return "Error: Google API key not configured"
        
        try:
            generation_config = {
                "temperature": kwargs.get("temperature", 0.7),
                "max_output_tokens": kwargs.get("max_tokens", 1000),
            }
            response = self.model.generate_content(
                prompt,
                generation_config=generation_config
            )
            return response.text
        except Exception as e:
            return f"Error generating response from Gemini: {str(e)}"
    
    def get_model_name(self) -> str:
        """Get model name"""
        return f"Google {self.model_name}"
