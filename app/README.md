# lanchain research app 

## setup

* To run locally, install the dependencies using ```pip install -r requirements.txt```
* Get GROQ_API_KEY from [Groq Console](https://console.groq.com/keys) and replace ```<YOUR_GROQ_API_KEY>``` in the .env file with this API key
* Similarly, create TAVILY_API_KEY from [Tavily Homepage](https://app.tavily.com/home) and replace ```<YOUR_TAVILY_KEY_KEY>``` in the .env file with this API key

## Running locally (ensure setup is completed before this step)

1.  **Without using docker**
    * Uncomment [Line 15](./app/langchain_deep_research.py#L15) from ```langchain_deep_research.py```
    * Run ```streamlit run app.py``` to start the UI and interacting with the app

2.  **With Docker**
    * Keep [Line 15](./app/langchain_deep_research.py#L15) in ```langchain_deep_research.py``` as it is (commented)
    * Build the image using
      ```docker
      docker build -t research-agent:latest .
      ```
    * To run the app,
      ```docker
      docker run --env-file .env -p 8051:8051 research-agent:latest 
      ```
      
## Testing the app
* After following either of the steps in ```Running locally```, open ```http://localhost:8051``` to start using the app

    ![image](https://github.com/user-attachments/assets/b50c6526-1898-4f4d-a747-3578a1cf503a)
