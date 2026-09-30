# Archive service — design

## 1. Purpose
Users keep their monthly bank statements and invoices in one archive.

## 2. Accounts
One account per household; up to five members.

## 3. Uploads
Uploads are limited to 10 MB per file. Larger files are rejected with a clear message.

## 4. Storage
Files are stored encrypted at rest; keys are per household.

## 5. Search
Full-text search over PDF text, updated within one minute of upload.

## 6. Retention
Files are kept until the household deletes them.

## 7. Monthly archive
At the end of each month, members upload the month's combined archive (a single PDF, typically 40–60 MB) so the whole month can be restored in one step.

## 8. Out of scope
Mobile apps; sharing outside the household.
