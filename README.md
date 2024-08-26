# terraform-practice

This is a practice project for learning Terraform.

On one of my jobs we used to create the following infrastructure for static websites.

1. S3 bucket for the hugo templates
1. S3 bucket for the generated website
1. API Gateway to trigger the lambda function. It used to fetch data from a headless CMS put it into jsons, and run hugo templates.
1. Lambda function to generate the website
1. CloudFront distribution to serve the website

In this project I am trying to recreate the same infrastructure using Terraform. I cut some corners to keep it simple, but I want to add hugo as a lambda layer later. I also don't have a headless CMS to fetch data from, so I am not fetching. Insead, the lambda currently just logs the contents of one bucket, and adds new file to another one.