import azure.functions as func
import datetime
import json
import logging
import os
import azure.identity
import openai
from dotenv import load_dotenv

app = func.FunctionApp()


@app.route(route="HttpExample")
@app.queue_output(arg_name="msg", queue_name="outqueue", connection="AzureWebJobsStorage")
def HttpExample(req: func.HttpRequest, msg: func.Out [func.QueueMessage]) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')

    load_dotenv("../.env")
    # Change to logging.DEBUG for more verbose logging from Azure and OpenAI SDKs
    logging.basicConfig(level=logging.WARNING)

    if not os.getenv("AZURE_OPENAI_SERVICE") or not os.getenv("AZURE_OPENAI_GPT_DEPLOYMENT"):
        logging.warning("AZURE_OPENAI_SERVICE and AZURE_OPENAI_GPT_DEPLOYMENT environment variables are empty. See README.")
        exit(1)

    credential = azure.identity.DefaultAzureCredential(
        managed_identity_client_id=os.getenv("AZURE_MSI_ID")
    )
    token_provider = azure.identity.get_bearer_token_provider(credential, "https://cognitiveservices.azure.com/.default")

    client = openai.AzureOpenAI(
        api_version="2024-03-01-preview",
        azure_endpoint=f"https://{os.getenv('AZURE_OPENAI_SERVICE')}.openai.azure.com",
        azure_ad_token_provider=token_provider,
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

    return func.HttpResponse(
        f"{response.choices[0].message.content}",
        status_code=200
        )

