# lanchain research app setup

* To run locally, install the dependencies using ```pip install -r requirements.txt```
* Get GROQ_API_KEY from [Groq Console](https://console.groq.com/keys) and replace ```<YOUR_GROQ_API_KEY>``` in the .env file with this API key
* Similarly, create TAVILY_API_KEY from [Tavily Homepage](https://app.tavily.com/home) and replace ```<YOUR_TAVILY_KEY_KEY>``` in the .env file with this API key
* Uncomment [Line 15](./app/langchain_deep_research.py#L15) from ```langchain_deep_research.py```
* Run ```streamlit run app.py``` to start the UI and interacting with the app
