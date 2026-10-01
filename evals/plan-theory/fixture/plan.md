# Plan: move user emails to the contacts table

Goal: every user's email lives in `contacts.email`; `users.email` goes away.
The users table has 2.3 million rows. The service must stay up throughout.

## Steps

1. Add the column `contacts.email` (text, nullable).
2. Deploy the application version that reads and writes email only through
   `contacts.email`.
3. Drop the column `users.email`.
4. Backfill `contacts.email` from `users.email` for every user.
5. Make `contacts.email` NOT NULL.

## Rollback

Redeploy the previous application version.

## Done when

Every user can log in with their email and `users.email` no longer exists.
