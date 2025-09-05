import boto3
import json
import os
 
s3 = boto3.client("s3")
translate = boto3.client("translate")
response_bucket = os.environ["RESPONSE_BUCKET"]
 
# ...existing code...

def lambda_handler(event, context):
    for record in event["Records"]:
        bucket = record["s3"]["bucket"]["name"]
        key = record["s3"]["object"]["key"]

        try:
            # Download file
            obj = s3.get_object(Bucket=bucket, Key=key)
            request_data = json.loads(obj["Body"].read())

            source = request_data.get("SourceLanguageCode", "auto")
            texts  = request_data.get("TextList", [])

            # Add target languages: German, French, Hausa
            target_languages = {
                "de": "German",
                "fr": "French",
                "ha": "Hausa"
            }

            translations = {}
            for code, lang in target_languages.items():
                translated = []
                for t in texts:
                    result = translate.translate_text(
                        Text=t, SourceLanguageCode=source, TargetLanguageCode=code
                    )
                    translated.append(result["TranslatedText"])
                translations[lang] = translated

            # Save result
            output_key = key.replace("requests/", "translations/")
            output_data = {
                "SourceLanguageCode": source,
                "OriginalText": texts,
                "Translations": translations
            }

            s3.put_object(
                Bucket=response_bucket,
                Key=output_key,
                Body=json.dumps(output_data, ensure_ascii=False).encode("utf-8")
            )

            print(f"✅ Translated file saved to {response_bucket}/{output_key}")

        except Exception as e:
            print(f"❌ Error: {str(e)}")
