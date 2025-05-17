
import os
import re
import json
from langchain_tavily import TavilySearch

from langchain_ollama import ChatOllama
from langchain.prompts import PromptTemplate
from langgraph.prebuilt import create_react_agent
from pprint import pprint
from dotenv import load_dotenv
from langchain_groq import ChatGroq


# load_dotenv(override=True)


tools = [
    TavilySearch(max_results=15)
]


prompt = "You are an expert researcher agent. Given a search query, use the tool to get relevant results along with their sources"
retrieval_llm = ChatGroq(
    model="llama3-8b-8192",
    temperature=0,
    max_tokens=None,
    timeout=None,
    max_retries=2,
)

retrieval_agent = create_react_agent(
    model=retrieval_llm,
    tools=tools,
    prompt=prompt
)


def retrieve_snippets(topic: str) -> list[dict]:
    """
    Ask the React agent to gather top 5 points on `topic` as JSON.
    Returns a Python list of {"url": ..., "point": ...}.
    """
    result = retrieval_agent.invoke({"messages": [("user", topic)]})
    raw = result['messages'][2].content
    # pprint(raw)
    print()
    try:
        return json.loads(raw)
    except json.JSONDecodeError as e:
        raise ValueError(f"Failed to parse JSON from retrieval agent: {e}\n\nRaw output:\n{raw}")


template = """
You are a research assistant. You've been given:
- A topic: “{topic}”
- A JSON object in “{contents}” that contains a field “results”: a list of objects each with “url”, “title”, and “content”.

Your task is to write a concise, well-structured overview of “{topic}” by synthesizing the entries in “results” 
(Make sure not to generate new facts). 
For every factual claim or key point you make, attach an inline citation using the URL of the source 
(url key in the json object should be used in citation as it is and do not add anything new in the url. 
If the url contains github.com, then use the url as it is and do not generate anything ). 
Use this format for citations:
  (source: <url>)

Do not invent URLs or include any sources not present in the provided “results”. You may combine multiple results to form a cohesive narrative, but each sentence that presents a fact must end with at least one `(source: …)` citation.

"""

prompt = PromptTemplate(
    input_variables=["topic", "contents"],
    template=template,
)


synthesis_llm = ChatGroq(
    model="deepseek-r1-distill-llama-70b",
    temperature=0,
    max_tokens=None,
    timeout=None,
    max_retries=2,
)
synthesis_chain = prompt | synthesis_llm


def synthesize_answer(topic: str, snippets: list[dict]) -> str:
    op = synthesis_chain.invoke({"topic": topic, "contents": snippets})
    op = re.sub(r"<think>[\s\S]*?<\/think>", "", op.content)
    return op


def answer_with_live_web(topic: str) -> str:
    snippets = retrieve_snippets(topic)
    return synthesize_answer(topic, snippets)

