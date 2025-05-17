import streamlit as st
from langchain_deep_research import answer_with_live_web


def main():
    st.title("🔍 Research Assistant")
    st.write("Enter a topic below and get a concise, well-cited overview based on live web search.")

    topic = st.text_input("Topic", value="", placeholder="e.g., React framework Redux")
    if st.button("Analyze Topic"):
        if not topic.strip():
            st.warning("Please enter a topic to analyze.")
            return
        
        with st.spinner("Generating overview..."):
            overview = answer_with_live_web(topic)

        st.subheader("📝 Overview")
        st.write(overview)


if __name__ == "__main__":
    main()