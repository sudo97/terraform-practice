import {
  ListObjectsV2Command,
  PutObjectCommand,
  S3Client,
} from "@aws-sdk/client-s3";
import {
  Handler,
  APIGatewayProxyEvent,
  APIGatewayProxyResult,
} from "aws-lambda";

export const handler: Handler = async (
  event: APIGatewayProxyEvent
): Promise<APIGatewayProxyResult> => {
  const s3 = new S3Client({ region: "us-east-1" });

  const listObjectsCommand = new ListObjectsV2Command({
    Bucket: process.env.SOURCE_BUCKET,
  });

  try {
    const data = await s3.send(listObjectsCommand);

    data.Contents?.forEach((object) => {
      console.log(object.Key);
    });

    console.log("Success", data);

    const items = data.Contents?.map((object) => object.Key).join(", ");

    await s3.send(
      new PutObjectCommand({
        Bucket: process.env.DESTINATION_BUCKET,
        Key: `test-${new Date().toISOString()}.txt`,
        Body: "Hello, World!" + new Date().toISOString(),
      })
    );

    return {
      statusCode: 200,
      body: JSON.stringify({ message: items }),
    };
  } catch (err) {
    console.log("Error", err);
    return {
      statusCode: 500,
      body: JSON.stringify({
        message: "Internal server error: " + (err as Error).message,
      }),
    };
  }
};
