import logging
import os

import openai
from dotenv import load_dotenv

load_dotenv("../.env")
# Change to logging.DEBUG for more verbose logging from Azure and OpenAI SDKs
logging.basicConfig(level=logging.WARNING)


if (
    not os.getenv("AZURE_OPENAI_SERVICE")
    or not os.getenv("AZURE_OPENAI_GPT_DEPLOYMENT")
    or not os.getenv("AZURE_OPENAI_API_KEY")
):
    logging.warning(
        "AZURE_OPENAI_SERVICE, AZURE_OPENAI_GPT_DEPLOYMENT and AZURE_OPENAI_API_KEY environment variables are empty. See README."
    )
    exit(1)


client = openai.AzureOpenAI(
    api_version="2024-03-01-preview",
    azure_endpoint=f"https://{os.getenv('AZURE_OPENAI_SERVICE')}.openai.azure.com",
    api_key=os.getenv("AZURE_OPENAI_KEY"),
)

response = client.chat.completions.create(
    # For Azure OpenAI, the model parameter must be set to the deployment name
    model=os.getenv("AZURE_OPENAI_GPT_DEPLOYMENT"),
    temperature=0.7,
    n=1,
    messages=[
        {"role": "system", "content": "You are a helpful assistant that makes lots of Star Wars references and uses emojis."},
        # {"role": "user", "content": "Write a haiku about Star wars clone force 99's member Corsshair who wants to find Omega"},
        {"role": "user", "content": "Write a haiku about Star wars Rebels Series member Captain Syndulla"},
    ],
)

print("Response: ")
print(response.choices[0].message.content)
