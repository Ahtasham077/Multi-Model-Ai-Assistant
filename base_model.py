"""
Base class for AI model integrations
"""
from abc import ABC, abstractmethod
from typing import Dict, Any


class AIModel(ABC):
    """Abstract base class for AI model integrations"""
    
    def __init__(self, api_key: str):
        """
        Initialize the AI model with API key
        
        Args:
            api_key: API key for the model
        """
        self.api_key = api_key
        
    @abstractmethod
    def generate_response(self, prompt: str, **kwargs) -> str:
        """
        Generate a response from the AI model
        
        Args:
            prompt: The input prompt/message
            **kwargs: Additional parameters for the model
            
        Returns:
            str: The generated response
        """
        pass
    
    @abstractmethod
    def get_model_name(self) -> str:
        """
        Get the name of the AI model
        
        Returns:
            str: Model name
        """
        pass
    
    def is_available(self) -> bool:
        """
        Check if the model is available (API key is set)
        
        Returns:
            bool: True if model is available
        """
        return bool(self.api_key and self.api_key != "your_api_key_here")
