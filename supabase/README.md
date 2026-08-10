# Future Odyssey Supabase

Project: `okbrapkebgyieyvuxamb` (`ap-northeast-2`)

## Data model

- `classrooms`: class code and classroom identity
- `student_profiles`: stable student ID, class membership, job, balance, first-login state, account status
- `student_progress`: independent growth stage and activity counters
- `feature_unlocks`: append-only student feature unlock records
- `private.student_credentials`: bcrypt PIN hashes, failed-attempt counter, lock expiry
- `private.student_sessions`: SHA-256 hashes of random 8-hour session tokens

Public tables have forced RLS and explicit deny-all policies. The browser cannot select or mutate them directly. The site calls narrowly scoped `SECURITY DEFINER` RPCs through a same-origin API route. The API route keeps the opaque session token in an `HttpOnly`, `SameSite=Strict` cookie.

## Runtime variables

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`

Both are configured in Sites production runtime. The publishable key is not a service-role secret.

## Test accounts

- First-login flow: class `603`, name `김민준`, temporary PIN `3841`
- Returning-student flow: class `603`, name `김하늘`, PIN `2580`

Replace these demonstration records before importing a real roster.

## Verification

1. Sign in as 김민준 and set a new four-digit PIN.
2. Complete the first basic-job task and confirm that the wallet and bank unlock together with the first salary.
3. Save 100꿈 and confirm that housing unlocks.
4. Sign out, sign back in, and confirm that progress is restored from Supabase.
5. Enter a wrong PIN five times and confirm the ten-minute security wait.
6. Attempt direct REST table access with the publishable key and confirm that no student rows are returned.

The remote migrations applied to Supabase are named `student_accounts_and_feature_unlocks` and `deny_direct_table_access`.
