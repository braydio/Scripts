#!/usr/bin/env python3
"""Fetch financial news in RSS feed style via OpenAI's gpt-5o-nano model."""

from __future__ import annotations

import os
from openai import OpenAI


def fetch_financial_news() -> None:
    """Request financial news headlines using web search and print RSS-style output."""
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise RuntimeError("OPENAI_API_KEY environment variable is not set")

    client = OpenAI(api_key=api_key)

    prompt = (
        "Provide an RSS feed style list of the latest financial news from top news outlets."  # noqa: E501
    )

    response = client.responses.create(
        model="gpt-5o-nano",
        input=[
            {
                "role": "user",
                "content": [{"type": "input_text", "text": prompt}],
            }
        ],
        tools=[{"type": "web_search"}],
    )

    if response.output:
        blocks = response.output[0].get("content", [])
        text = "\n".join(
            block["text"] for block in blocks if block.get("type") == "output_text"
        )
        print(text)
    else:
        print("No output received from model")


if __name__ == "__main__":
    fetch_financial_news()
