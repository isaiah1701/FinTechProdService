# Submission Pack

This directory contains upload-ready `.docx` files for the assessment prompts.

Generated files:

1. `01_postgres_provisioning_least_privilege.docx`
2. `02_credential_handling_no_plaintext.docx`
3. `03_idempotent_consumer_dlq.docx`
4. `04_github_actions_cicd.docx`
5. `05_terraform_cloud_resources_plan.docx`
6. `06_observability_business_o11y.docx`
7. `07_readme_platform_mapping.docx`

Regenerate with:

```bash
.venv/bin/python -m pip install -r submission/requirements.txt
.venv/bin/python submission/build_submission_docx.py
```
