# Research Hop – Modules 1 and 2 (foundation, home page, admin)

Needs Flutter 3.27 or newer.

## 1. Create the project and copy the files
```
flutter create research_hop --platforms web
```
Copy everything from this folder into `research_hop/`, replacing what exists
(pubspec.yaml, analysis_options.yaml, lib/, web/, test/, assets/).
Delete nothing else. Then:
```
flutter pub get
```
If `pub get` is slow on weak internet, run it once and leave it: packages are cached on
your computer, so every later run is fast (`flutter pub get --offline` never touches the network).

## 2. Add your Supabase keys
Open `assets/env/app.env` and fill in:
```
SUPABASE_URL=https://xxxx.supabase.co
SUPABASE_ANON_KEY=your anon / publishable key
```
Use ONLY the anon (publishable) key. Never the service_role / secret key.
The app shows a red warning page if it detects a secret key.

## 3. Supabase dashboard settings
Authentication > URL Configuration
- Site URL: your Cloudflare address (or http://localhost:5000 while testing)
- Redirect URLs: add http://localhost:5000 and your Cloudflare address

Authentication > Providers > Google: enable it and paste the Google client ID/secret
(Google Cloud Console redirect URI = the callback URL Supabase shows you).

Authentication > Providers > Email: for easy testing, turn off "Confirm email".

## 3b. Make the admin pages update live (run once)
SQL Editor > paste the contents of `supabase_002_admin_realtime.sql` > Run.
(If it says a table is already in the publication, that line is already done.)

## 3c. Run migration 003 (cash payments, profile photos) once
SQL Editor > paste `supabase_003_cash_avatars.sql` > Run.
It adds: cash payment for any student, private course notes, the public
"avatars" bucket for profile photos, and the "payment received" notification.

## 4. Backfill profiles for accounts created before the schema
SQL Editor:
```
insert into public.profiles (id, full_name)
select id, coalesce(raw_user_meta_data->>'full_name', raw_user_meta_data->>'name','')
from auth.users on conflict do nothing;
```
(Then make sure your admin row has role = 'admin'.)

## 5. Run
```
flutter run -d chrome --web-port 5000
flutter test
```
Send me any analyzer or compile errors and I will fix them.

## 6. Deploy to Cloudflare Pages
```
flutter build web --release
```
Upload `build/web`. The `_redirects` file makes page refreshes work.
Note: app.env is bundled into the build; that is fine because it only holds the anon key.

## Known limits (fixed in later modules)
- Fonts load from Google at runtime (will be bundled in hardening).
- Opening a deep link while signed out goes to login and the target is lost.
- Teacher and student pages are placeholders until their modules.
- Admin overview counts read the first 1000 rows of each table; fine for now.
