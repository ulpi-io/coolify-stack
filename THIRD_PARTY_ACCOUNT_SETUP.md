# Third-Party Account and Application Setup

This is the owner checklist for creating every third-party developer application used by the production stack. It is organized by provider console so one provider can be completed before moving to the next.

The checklist covers the application contracts implemented by Postiz, SocialReply, Albert, TeamToast/OpenKudos, QM, Plane, Kensi, Clavinci, Record Cloud, Lokei, n8n, and Buzz.

## How to use this checklist

1. Complete the **Core** entries first. Entries marked **Existing** should be corrected or reviewed, not recreated.
2. Use a different provider application for every numbered entry unless the entry explicitly says that sharing is allowed.
3. Enter every callback and webhook exactly as written, including any trailing slash.
4. Keep client secrets, access tokens, private keys, service-account JSON, verify-token values, and screenshots containing them out of Git.
5. For each completed entry, retain this non-secret handoff record:
   - provider and application name;
   - owning business/account;
   - application or client ID;
   - secret-manager location, not the secret itself;
   - enabled products/scopes;
   - review, verification, or Live-mode state;
   - credential expiry or renewal date, where applicable.
6. Do not enable provider Live mode or webhook verification until the public callback hostname has valid DNS and TLS.

Status labels used below:

- **Create**: a new dedicated provider application or resource is required.
- **Finish existing**: credentials already exist, but configuration, products, review, or runtime wiring remains incomplete.
- **After deployment**: create the provider record now, but defer callback verification until the service is publicly reachable.
- **Optional**: create only when that connector is selected for production use.

## Non-negotiable separation rules

- Never share Meta applications across Postiz, SocialReply, or Albert.
- SocialReply Instagram and Messenger intentionally share one `META_*` application. Its WhatsApp credentials are separate `WHATSAPP_*` credentials.
- Never share Slack applications across Postiz, Albert, TeamToast, QM, or Plane.
- Postiz TikTok Content Posting, SocialReply TikTok Business Messaging, SocialReply TikTok Ads, and Albert TikTok are separate applications.
- Postiz may use one Google Web OAuth client for YouTube and Google Business Profile when both callbacks are registered.
- SocialReply's sign-in/Sheets Google client and its YouTube Google client are separate.
- Google, Apple, and GitHub sign-in clients are dedicated per deployed product because their domains, callbacks, ownership, and rotation boundaries differ.

## Recommended completion order

- [ ] 1. Meta
- [ ] 2. Google Cloud
- [ ] 3. LinkedIn
- [ ] 4. TikTok
- [ ] 5. Slack
- [ ] 6. Microsoft Entra, Azure Bot, and Teams
- [ ] 7. Apple Developer
- [ ] 8. GitHub
- [ ] 9. Twilio
- [ ] 10. Telegram
- [ ] 11. Optional publishing providers
- [ ] 12. Dynamic n8n credentials and Buzz identity verification

---

## 1. Meta

Console: [Meta for Developers — My Apps](https://developers.facebook.com/apps/)

Complete Meta Business Verification before requesting Advanced Access or moving production applications to Live mode. Generate a different random webhook verify token for every application that needs one. A verify token is a value we choose and store on both sides; it is not the Meta app secret.

Current Meta portfolio snapshot (2026-08-05):

- The five applications accessible to the current Meta administrator are managed by `Open Growth Group` (`1561043185808404`).
- `ConFYI Post` remains Live. The four newly created applications remain unpublished/in development.
- The older `ConFYI-IG` application is not accessible to the current Meta administrator and is tracked separately under META-02.

### META-01 — ConFYI Post Facebook Pages and Facebook-linked Instagram

- [x] **Status: Done — Core**
- Application name: `ConFYI Post`
- Meta app ID: `2540383713069356`
- Business portfolio: `Open Growth Group` (`1561043185808404`), connected on 2026-08-05.
- Mode: Live; the ownership update did not change its existing publishing state or products.
- Use one dedicated Meta application for these two ConFYI Post connectors only.
- Add the Facebook Login for Business, Facebook Pages, and Instagram Graph API products needed by the app dashboard.
- OAuth redirect URIs:
  - `https://post.con.fyi/integrations/social/facebook`
  - `https://post.con.fyi/integrations/social/instagram`
- Facebook permissions:
  - `pages_show_list`
  - `business_management`
  - `pages_manage_posts`
  - `pages_manage_engagement`
  - `pages_read_engagement`
  - `read_insights`
- Facebook-linked Instagram permissions:
  - `instagram_basic`
  - `pages_show_list`
  - `pages_read_engagement`
  - `business_management`
  - `instagram_content_publish`
  - `instagram_manage_comments`
  - `instagram_manage_insights`
- Save for deployment:
  - `FACEBOOK_APP_ID=2540383713069356`
  - `FACEBOOK_APP_SECRET` — stored in encrypted Coolify production environment storage; never commit it.
- Production deployment completed on 2026-08-05. The existing standalone Instagram credentials were preserved unchanged, and the replacement Postiz container passed its health check.
- Finish by testing both a Facebook Page connection and an Instagram professional account linked to a Facebook Page.

### META-02 — ConFYI Post Instagram Business Login

- [ ] **Status: Existing; administrator access and ownership verification blocked — Core**
- Do not create a duplicate. This is the existing Instagram standalone application.
- Application name: `ConFYI-IG`
- Instagram app ID: `1047378704339939`
- Current access blocker: opening this app ID with the current Meta administrator redirects to My Apps, and the application is absent from the five accessible admin apps.
- Required owner action: grant the current administrator access or connect/transfer the application to `Open Growth Group`, then re-verify the configuration below.
- OAuth redirect URI:
  - `https://post.con.fyi/integrations/social/instagram-standalone`
- Data deletion instructions URL:
  - `https://con.fyi/con-fyi-post/user-data-deletion/`
- Webhooks are not required for ConFYI Post's standalone Instagram publishing integration and remain disabled.
- Development Instagram accounts added:
  - `thecasualleader`
  - `ciprianspiridon`
- Permissions:
  - `instagram_business_basic`
  - `instagram_business_content_publish`
  - `instagram_business_manage_comments`
  - `instagram_business_manage_insights`
- Save for deployment:
  - `INSTAGRAM_APP_ID=1047378704339939`
  - `INSTAGRAM_APP_SECRET`
- App Review/Business Verification and Live mode are required before connecting non-tester professional accounts.
- Do not place this application's ID or secret in `FACEBOOK_*`.

### META-03 — ConFYI Post Threads

- [x] **Status: Created and configured as far as the current runtime permits — Core**
- Application name: `ConFYI Post Threads`
- Meta dashboard app ID: `2010438396257144`
- Threads product app ID: `1752436635889997`; use this value for `THREADS_APP_ID`.
- Business portfolio: `Open Growth Group` (`1561043185808404`).
- Mode: In development/unpublished.
- Add the Threads API product.
- OAuth redirect URI:
  - `https://post.con.fyi/integrations/social/threads`
- Permissions:
  - `threads_basic`
  - `threads_content_publish`
  - `threads_manage_replies`
  - `threads_manage_insights`
- All four permissions are Ready for testing.
- Basic metadata is saved with the ConFYI Post domains, Utility & productivity category, and canonical ConFYI Post privacy, terms, and user-data-deletion pages.
- [ ] Implement real deauthorization and data-deletion callback handlers in the ConFYI Post runtime, deploy them with valid TLS, enter both URLs in Threads Settings, and save the product form.
- Do not substitute the OAuth redirect or a static legal page for either required signed-request callback. The current runtime has no handlers for them, which is why Meta reports `Form can't be saved`.
- Save for deployment:
  - `THREADS_APP_ID=1752436635889997`
  - `THREADS_APP_SECRET` — stored in encrypted Coolify production environment storage; never commit it.
- Production environment deployment completed on 2026-08-05. This does not remove the callback-handler blocker above or publish the Meta application.

### META-04 — SocialReply Instagram and Facebook Messenger

- [x] **Status: Created, configured, and deployed; webhook verification remains — Core**
- Application name: `SocialReply Channels`
- Meta app ID: `5366945603530693`
- Business portfolio: `Open Growth Group` (`1561043185808404`).
- Mode: In development/unpublished.
- This one SocialReply application is intentionally shared by Instagram Business Login and Facebook Messenger.
- Instagram OAuth redirect URI:
  - `https://api.socialreply.ai/api/v1/channel-accounts/instagram/callback`
- Messenger OAuth redirect URI:
  - `https://api.socialreply.ai/api/v1/channel-accounts/facebook_messenger/callback`
- Webhooks:
  - `https://api.socialreply.ai/webhooks/instagram`
  - `https://api.socialreply.ai/webhooks/facebook_messenger`
- Data deletion callback:
  - `https://api.socialreply.ai/webhooks/meta/data-deletion`
- Instagram permissions:
  - `instagram_business_basic`
  - `instagram_business_manage_messages`
  - `instagram_business_manage_comments`
  - `instagram_business_manage_insights`
- Messenger permissions:
  - `pages_show_list`
  - `pages_manage_metadata`
  - `pages_messaging`
  - `pages_read_engagement`
- Instagram subscribed fields:
  - `comments`
  - `messages`
  - `messaging_postbacks`
  - `mentions`
- Messenger subscribed fields:
  - `messages`
  - `messaging_postbacks`
  - `message_deliveries`
  - `message_reads`
  - `feed`
- The requested Instagram and Messenger permissions are Ready for testing.
- The Messenger Webhooks extension is installed. Leave its callback unverified until the production endpoint and verify token are ready.
- Basic metadata uses the canonical SocialReply privacy and terms pages plus the real Meta data-deletion callback.
- Save for deployment:
  - `META_APP_ID=5366945603530693`
  - `META_APP_SECRET` — stored in encrypted Coolify production environment storage; never commit it.
  - `META_WEBHOOK_VERIFY_TOKEN` — generated and stored in encrypted Coolify production environment storage.
  - `META_DATA_DELETION_STATUS_ORIGIN=https://socialreply.ai`
- Production environment deployment completed on 2026-08-05. All long-running SocialReply containers passed their health checks; the Meta webhook challenge remains intentionally deferred.
- Do not attempt the live webhook challenge until `api.socialreply.ai` points to the production server with valid TLS.

### META-05 — SocialReply WhatsApp Business

- [x] **Status: Created and configured; production onboarding remains deferred — Core**
- Application name: `SocialReply Business Messaging`
- Meta app ID: `2096560057565414`
- Embedded Signup configuration ID: `2166695507610241`
- Business portfolio: `Open Growth Group` (`1561043185808404`).
- Mode: In development/unpublished.
- Create a separate Meta business application, add WhatsApp Cloud API, and create an Embedded Signup configuration.
- Webhook:
  - `https://api.socialreply.ai/webhooks/whatsapp`
- [ ] Complete Meta Business Verification.
- [ ] Through Embedded Signup, connect the production WABA, register and verify an SMS/voice-capable phone number, wait for display-name approval, store the credentials, and confirm the WABA webhook subscription after deployment.
- Save for deployment:
  - `WHATSAPP_APP_ID=2096560057565414`
  - `WHATSAPP_APP_SECRET` — stored in encrypted Coolify production environment storage; never commit it.
  - `WHATSAPP_EMBEDDED_SIGNUP_CONFIG_ID=2166695507610241`
  - `WHATSAPP_WEBHOOK_VERIFY_TOKEN` — generated separately from the other Meta token and stored in encrypted Coolify production environment storage.
- Production environment deployment completed on 2026-08-05. This does not complete Business Verification, WABA/phone onboarding, display-name approval, or webhook subscription.
- Do not reuse SocialReply's `META_*` application or verify token.

### META-06 — Albert Meta channels

- [x] **Status: Created and configured; verify after deployment**
- Application name: `Albert Channels`
- Meta app ID: `2185146699102820`
- Business portfolio: `Open Growth Group` (`1561043185808404`).
- Mode: In development/unpublished.
- Create an Albert-owned Meta application and enable only the products actually used: WhatsApp, Facebook Pages/Messenger, and Instagram.
- Enabled use cases: Messenger from Meta, Instagram API, and WhatsApp Business Messaging.
- Ready for testing:
  - Messenger: `pages_manage_metadata`, `pages_messaging`, `pages_show_list`, and the Messenger Webhooks extension.
  - Instagram: `instagram_business_basic`, `instagram_business_manage_messages`, and the Human Agent feature used by the adapter's tagged replies.
  - WhatsApp: `whatsapp_business_management` and `whatsapp_business_messaging`.
- Basic metadata uses `api.albert.con.fyi`, `albert.con.fyi`, and `www.albert.con.fyi`, the live Albert privacy/terms pages, deletion instructions in the privacy page, and the Messaging category.
- Matching webhooks:
  - `https://api.albert.con.fyi/api/v1/webhooks/whatsapp`
  - `https://api.albert.con.fyi/api/v1/webhooks/facebook`
  - `https://api.albert.con.fyi/api/v1/webhooks/instagram`
- Store channel credentials and verify tokens through Albert's encrypted channel settings. They are not all process-level environment variables.
- [ ] Generate distinct verify tokens, store the app secret and channel credentials through Albert's encrypted settings, then verify the three production webhooks.
- [ ] Complete the production WABA/phone-number and Business Verification steps before enabling WhatsApp for ordinary users.
- The current Messenger use-case UI does not expose a separate Human Agent feature. Reconfirm Meta's entitlement/review behavior before promising Messenger replies outside the standard 24-hour window.
- Test the exact supported inbound and outbound behavior for each channel; webhook verification alone does not prove Albert dispatches normal outbound replies for every channel.

---

## 2. Google Cloud

Consoles:

- [Google Cloud projects](https://console.cloud.google.com/projectselector2/home/dashboard)
- [API Library](https://console.cloud.google.com/apis/library)
- [OAuth consent screen](https://console.cloud.google.com/apis/credentials/consent)
- [Credentials](https://console.cloud.google.com/apis/credentials)

For each project, configure the consent screen, authorized domains, support/developer contacts, scopes, test users while in Testing, and publishing/verification state. Use Web application clients, not Desktop clients.

### GOOGLE-01 — ConFYI Post YouTube and Google Business Profile

- [ ] **Status: Configured and deployed; Google Business Profile local-post API access remains pending — Core**
- Existing Google Cloud project retained and renamed to `ConFYI Post`:
  - Project ID: `postiz-504505`
  - Project number: `806355414137`
  - Current resource location: `ciprianspiridon.com`
  - `cip@opengrowthgroup.co` is an Owner.
- Existing Web application OAuth client retained and renamed to `ConFYI Post Google Channels`:
  - Client ID: `806355414137-19hmits7aqp6uhcu9716cscadi4c1b9q.apps.googleusercontent.com`
- Google Auth branding saved on 2026-08-06:
  - Application name: `ConFYI Post`
  - User support and developer contact: `cip@opengrowthgroup.co`
  - Homepage: `https://con.fyi/con-fyi-post/`
  - Privacy policy: `https://con.fyi/con-fyi-post/privacy-policy/`
  - Terms of service: `https://con.fyi/con-fyi-post/terms-of-service/`
  - Authorized domain: `con.fyi`
- Audience remains **Internal**. Verification Center reports that verification is not required while the app is Internal; the app was not made External or published.
- APIs enabled and verified:
  - [x] YouTube Data API v3 (`youtube.googleapis.com`)
  - [x] YouTube Analytics API (`youtubeanalytics.googleapis.com`)
  - [x] My Business Account Management API (`mybusinessaccountmanagement.googleapis.com`)
  - [x] My Business Business Information API (`mybusinessbusinessinformation.googleapis.com`)
  - [ ] Google My Business API v4 (`mybusiness.googleapis.com`) for `accounts.locations.localPosts`; this legacy service is access-gated and is not exposed in this project's API Library. Request/obtain Google Business Profile API access and non-zero quota before treating local-post publishing as complete.
- Authorized redirect URIs saved:
  - `https://post.con.fyi/integrations/social/youtube`
  - `https://post.con.fyi/integrations/social/gmb`
- Requested scopes include profile/email, YouTube read/write/upload/analytics/partner scopes, and `https://www.googleapis.com/auth/business.manage`.
- The same client pair is saved in Coolify under both integration contracts; values were compared in the live container without printing them:
  - `YOUTUBE_CLIENT_ID`
  - `YOUTUBE_CLIENT_SECRET`
  - `GOOGLE_GMB_CLIENT_ID`
  - `GOOGLE_GMB_CLIENT_SECRET`
- Production deployment completed on 2026-08-06. Only the Postiz resource was redeployed, and the resulting container was verified healthy.
- [ ] Before relying on users outside the current Google Workspace organization, change the audience to External and complete Google's verification requirements for the requested sensitive/restricted scopes.

### GOOGLE-02 — SocialReply sign-in and Google Sheets

- [ ] **Status: Create now; test after deployment — Core**
- Project/client name suggestion: `SocialReply Auth and Sheets`
- Enable Google Sheets API.
- Authorized redirect URIs:
  - `https://api.socialreply.ai/api/v1/auth/google/callback`
  - `https://api.socialreply.ai/api/v1/integrations/google_sheets/oauth/callback`
- Scopes:
  - `openid`
  - `profile`
  - `email`
  - `https://www.googleapis.com/auth/spreadsheets`
- Save for deployment:
  - `GOOGLE_CLIENT_ID`
  - `GOOGLE_CLIENT_SECRET`
  - `GOOGLE_REDIRECT_URI`
  - `GOOGLE_SHEETS_REDIRECT_URI`

### GOOGLE-03 — SocialReply YouTube

- [ ] **Status: Create now; test after deployment — Core**
- Use a separate project/client or at minimum a separate OAuth client and quota boundary from GOOGLE-02.
- Enable YouTube Data API v3.
- Authorized redirect URI:
  - `https://api.socialreply.ai/api/v1/channel-accounts/youtube/callback`
- Scope:
  - `https://www.googleapis.com/auth/youtube.force-ssl`
- Save for deployment:
  - `YOUTUBE_CLIENT_ID`
  - `YOUTUBE_CLIENT_SECRET`

### GOOGLE-04 — TeamToast Google Chat and Google sign-in

- [ ] **Status: Create — Core**
- Create one TeamToast Google Cloud project containing:
  - a Google Chat application;
  - a service account;
  - Google Workspace domain-wide delegation for required Directory access;
  - a Web OAuth client for user sign-in.
- OAuth redirect URI:
  - `https://api.teamtoast.ai/api/auth/google/callback`
- Google Chat webhook:
  - `https://api.teamtoast.ai/api/google-chat/webhook`
- Required capabilities/scopes include `chat.bot` and `admin.directory.user.readonly`.
- Save for deployment:
  - `GOOGLE_CHAT_PROJECT_NUMBER`
  - service-account JSON mounted as a read-only file referenced by `GOOGLE_CHAT_SERVICE_ACCOUNT_KEY_PATH`
  - `GOOGLE_CLIENT_ID`
  - `GOOGLE_CLIENT_SECRET`
  - `NEXT_PUBLIC_GOOGLE_CHAT_APP_URL`
- Never paste service-account JSON into Compose, Git, or an ordinary environment-value field.

### GOOGLE-05 — Plane sign-in

- [ ] **Status: Create — Core**
- Authorized redirect URIs:
  - `https://pm.con.fyi/auth/google/callback`
  - `https://pm.con.fyi/auth/mobile/google/callback/`
- Scopes: `openid`, `profile`, `email`.
- Enter the client ID and secret through Plane `/god-mode`; they are not stack Compose variables.
- Reference: [Plane Google OAuth setup](https://developers.plane.so/self-hosting/govern/google-oauth).

### GOOGLE-06 — Kensi sign-in

- [ ] **Status: Create — Core**
- Authorized redirect URI:
  - `https://api.kensi.ai/auth/social/google/callback-web`
- Save for deployment:
  - `GOOGLE_CLIENT_ID`
  - `GOOGLE_CLIENT_SECRET`
  - `GOOGLE_REDIRECT_URL`

### GOOGLE-07 — Clavinci sign-in

- [ ] **Status: Create after DNS — Core**
- Authorized redirect URI:
  - `https://api.clavinci.com/api/v1/auth/google/callback`
- Save for deployment:
  - `ULPI_OAUTH_GOOGLE_CLIENT_ID`
  - `ULPI_OAUTH_GOOGLE_CLIENT_SECRET`
  - `ULPI_OAUTH_REDIRECT_BASE=https://api.clavinci.com`
  - `ULPI_OAUTH_DASHBOARD_ORIGIN=https://www.clavinci.com`
- `api.clavinci.com` must resolve publicly and have valid TLS before OAuth testing.

### GOOGLE-08 — Record Cloud sign-in

- [ ] **Status: Create — Core**
- Authorized redirect URI:
  - `https://api.record.con.fyi/api/auth/callback/google`
- Scopes: `openid`, `profile`, `email`.
- Save for deployment:
  - `GOOGLE_CLIENT_ID`
  - `GOOGLE_CLIENT_SECRET`

### GOOGLE-09 — Lokei sign-in

- [ ] **Status: Create — Core**
- Authorized redirect URI:
  - `https://www.lokei.dev/api/auth/callback/google`
- Scopes: `openid`, `profile`, `email`.
- Save for deployment:
  - `AUTH_URL=https://www.lokei.dev`
  - `GOOGLE_CLIENT_ID`
  - `GOOGLE_CLIENT_SECRET`

---

## 3. LinkedIn

Console: [LinkedIn Developer Apps](https://www.linkedin.com/developers/apps)

### LINKEDIN-01 — Postiz personal and organization publishing

- [ ] **Status: Finish existing — Core**
- Use the existing dedicated Postiz LinkedIn application.
- Authorized redirect URLs:
  - `https://post.con.fyi/integrations/social/linkedin`
  - `https://post.con.fyi/integrations/social/linkedin-page`
- Required products/access:
  - Share on LinkedIn
  - Sign In with LinkedIn using OpenID Connect
  - Community Management API for organization workflows
  - any additional LinkedIn-approved product required to grant the literal organization scopes below
- Required scopes requested by the deployed Postiz image:
  - `openid`
  - `profile`
  - `w_member_social`
  - `r_basicprofile`
  - `rw_organization_admin`
  - `w_organization_social`
  - `r_organization_social`
- Save for deployment:
  - `LINKEDIN_CLIENT_ID`
  - `LINKEDIN_CLIENT_SECRET`
- The current error is a product/scope entitlement problem. Do not change Postiz code or remove requested scopes to make OAuth appear to work.

---

## 4. TikTok

Consoles:

- [TikTok for Developers](https://developers.tiktok.com/apps/)
- [TikTok for Business developer portal](https://business-api.tiktok.com/portal)

### TIKTOK-01 — Postiz Content Posting

- [ ] **Status: Finish existing — Core**
- Keep the existing Postiz developer application.
- Add Login Kit and Content Posting API with Direct Post.
- OAuth redirect URI:
  - `https://post.con.fyi/integrations/social/tiktok`
- Scopes:
  - `video.list`
  - `user.info.basic`
  - `video.publish`
  - `video.upload`
  - `user.info.profile`
  - `user.info.stats`
- Verify `post.con.fyi` in TikTok. Domain verification is needed for `pull_by_url`; `push_by_file` does not remove the OAuth/app-review requirements.
- Save for deployment:
  - `TIKTOK_CLIENT_ID`
  - `TIKTOK_CLIENT_SECRET`
- Complete production review before testing with ordinary users.

### TIKTOK-02 — SocialReply Business Messaging

- [ ] **Status: Create now; test after deployment — Core**
- Create in the TikTok for Business portal, not as a Postiz Content Posting app.
- OAuth redirect URI:
  - `https://api.socialreply.ai/api/v1/channel-accounts/tiktok/callback`
- Scopes:
  - `message.list.send`
  - `message.list.read`
  - `message.list.manage`
  - `user.account.type`
  - `video.list`
  - `comment.list`
  - `comment.list.manage`
- Save for deployment:
  - `TIKTOK_BUSINESS_APP_ID`
  - `TIKTOK_BUSINESS_APP_SECRET`

### TIKTOK-03 — SocialReply Ads

- [ ] **Status: Create now; test after deployment — Core**
- Create a separate TikTok for Business Ads application.
- OAuth redirect URI:
  - `https://api.socialreply.ai/api/v1/integrations/tiktok_ads/oauth/callback`
- Select the Ads permissions required by the SocialReply integration and record the approved scope string.
- Save for deployment:
  - `TIKTOK_ADS_APP_ID`
  - `TIKTOK_ADS_SECRET`
  - `TIKTOK_ADS_SCOPES`

### TIKTOK-04 — Albert TikTok

- [ ] **Status: Optional**
- Create only when enabling Albert's TikTok channel.
- Webhook:
  - `https://api.albert.con.fyi/api/v1/webhooks/tiktok`
- Store credentials through Albert's encrypted channel settings and validate the source-documented capability boundary before claiming outbound support.

---

## 5. Slack

Console: [Slack API — Your Apps](https://api.slack.com/apps/)

Create five separate Slack applications. Do not reuse a client ID, signing secret, bot token, or app-level token between products.

### SLACK-01 — Albert

- [ ] **Status: Create — Core**
- Webhooks:
  - `https://api.albert.con.fyi/api/v1/webhooks/slack`
  - `https://api.albert.con.fyi/api/v1/webhooks/slack/interactivity`
- Save for deployment:
  - `SLACK_CLIENT_ID`
  - `SLACK_CLIENT_SECRET`
  - `SLACK_SIGNING_SECRET`
  - `SLACK_BOT_USER_OAUTH_TOKEN`, when bot installation is enabled

### SLACK-02 — TeamToast

- [ ] **Status: Create — Core**
- OAuth redirect URI:
  - `https://api.teamtoast.ai/api/auth/slack/callback`
- Request URLs:
  - `https://api.teamtoast.ai/api/slack/commands`
  - `https://api.teamtoast.ai/api/slack/events`
  - `https://api.teamtoast.ai/api/slack/actions`
  - `https://api.teamtoast.ai/api/slack/install`
- Save for deployment:
  - `SLACK_CLIENT_ID`
  - `SLACK_CLIENT_SECRET`
  - `SLACK_SIGNING_SECRET`
  - `SLACK_BOT_USER_OAUTH_TOKEN`
  - `SLACK_APP_TOKEN` when Socket Mode/app-level access is enabled
  - `NEXT_PUBLIC_SLACK_CLIENT_ID`
  - `NEXT_PUBLIC_SLACK_APP_ID`

### SLACK-03 — QM

- [ ] **Status: Create — Core**
- Create from QM's source manifest at `src/slack/manifest.json`.
- Enable Socket Mode.
- Install the app to the selected workspace.
- Save for deployment:
  - `SLACK_BOT_TOKEN`
  - `SLACK_APP_TOKEN`
- Do not expose or modify QM's isolated Docker-in-Docker socket, containers, or volumes while adding these values.

### SLACK-04 — Plane

- [ ] **Status: Create — Core**
- Create from Plane's official Slack manifest.
- OAuth redirect URIs:
  - `https://pm.con.fyi/silo/api/slack/team/auth/callback/`
  - `https://pm.con.fyi/silo/api/slack/user/auth/callback/`
- Request URLs:
  - `https://pm.con.fyi/silo/api/slack/command/`
  - `https://pm.con.fyi/silo/api/slack/events`
  - `https://pm.con.fyi/silo/api/slack/action/`
  - `https://pm.con.fyi/silo/api/slack/options/`
- Save for deployment:
  - `SLACK_CLIENT_ID`
  - `SLACK_CLIENT_SECRET`
- Reference: [Plane Slack integration](https://developers.plane.so/self-hosting/govern/integrations/slack).

### SLACK-05 — Postiz

- [ ] **Status: Optional**
- OAuth redirect URI:
  - `https://post.con.fyi/integrations/social/slack`
- Save for deployment:
  - `SLACK_ID`
  - `SLACK_SECRET`
  - `SLACK_SIGNING_SECRET`

---

## 6. Microsoft Entra, Azure Bot, and Teams

Consoles:

- [Microsoft Entra app registrations](https://entra.microsoft.com/#view/Microsoft_AAD_RegisteredApps/ApplicationsListBlade)
- [Azure portal](https://portal.azure.com/)
- [Teams Developer Portal](https://dev.teams.microsoft.com/)

### MICROSOFT-01 — TeamToast Teams and Microsoft sign-in

- [ ] **Status: Create — Core**
- Create the TeamToast Entra application registration used for Microsoft OAuth.
- Create/configure the Azure Bot resource and render the Teams application package using TeamToast's `deploy/teams-manifest.json`.
- OAuth redirect URI:
  - `https://api.teamtoast.ai/api/auth/microsoft/callback`
- Bot messaging endpoint:
  - `https://api.teamtoast.ai/api/teams/activity`
- Delegated/application permissions required by source:
  - `User.Read`
  - `Organization.Read.All`
  - `User.Read.All`
- Grant tenant admin consent where required.
- Save for deployment:
  - `TEAMS_APP_ID`
  - `TEAMS_APP_PASSWORD`
  - `TEAMS_BOT_ID`
  - `MICROSOFT_CLIENT_ID`
  - `MICROSOFT_CLIENT_SECRET`
  - `NEXT_PUBLIC_TEAMS_APP_ID`

---

## 7. Apple Developer

Console: [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list)

Each product needs its own Sign in with Apple configuration. For each one, create or confirm the primary App ID, Services ID, website domain/return URL association, and Sign in with Apple private key. Generate the client secret outside Git and track its expiry for rotation.

### APPLE-01 — Kensi sign-in

- [ ] **Status: Create — Core**
- Return URL:
  - `https://api.kensi.ai/auth/social/apple/callback-web`
- Save for deployment:
  - `APPLE_CLIENT_ID`
  - `APPLE_CLIENT_SECRET`
  - `APPLE_REDIRECT_URL`
- Record the Team ID, Key ID, Services ID, secret expiry, and private-key secret-manager location.

### APPLE-02 — Record Cloud sign-in

- [ ] **Status: Create — Core**
- Return URL:
  - `https://api.record.con.fyi/api/auth/callback/apple`
- Save for deployment:
  - `APPLE_CLIENT_ID`
  - `APPLE_CLIENT_SECRET`
- Record the Team ID, Key ID, Services ID, secret expiry, and private-key secret-manager location.

---

## 8. GitHub

Console: [GitHub Developer Settings — OAuth Apps](https://github.com/settings/developers)

### GITHUB-01 — Plane sign-in

- [ ] **Status: Create — Core**
- Callback URLs required by Plane:
  - `https://pm.con.fyi/auth/github/callback/`
  - `https://pm.con.fyi/auth/mobile/github/callback/`
- If the GitHub OAuth App UI permits only one callback URL, use a separate mobile OAuth app rather than replacing the web callback.
- Enter the client ID and secret through Plane `/god-mode`.
- This is user sign-in only; Plane GitHub repository synchronization is a separate future integration.
- Reference: [Plane GitHub OAuth setup](https://developers.plane.so/self-hosting/govern/github-oauth).

### GITHUB-02 — Clavinci sign-in

- [ ] **Status: Create after DNS — Core**
- Authorization callback URL:
  - `https://api.clavinci.com/api/v1/auth/github/callback`
- Save for deployment:
  - `ULPI_OAUTH_GITHUB_CLIENT_ID`
  - `ULPI_OAUTH_GITHUB_CLIENT_SECRET`
- Do not test until `api.clavinci.com` resolves publicly with valid TLS.

### GITHUB-03 — Lokei sign-in

- [ ] **Status: Create — Core**
- Authorization callback URL:
  - `https://www.lokei.dev/api/auth/callback/github`
- Save for deployment:
  - `AUTH_URL=https://www.lokei.dev`
  - `GITHUB_CLIENT_ID`
  - `GITHUB_CLIENT_SECRET`

### GITHUB-04 — Postiz sign-in

- [ ] **Status: Optional**
- Create only if GitHub is selected as a Postiz login provider. This is not required for social publishing.
- Save for deployment:
  - `GITHUB_CLIENT_ID`
  - `GITHUB_CLIENT_SECRET`
- Confirm the callback generated by the pinned Postiz authentication configuration before saving the GitHub OAuth app.

---

## 9. Twilio

Console: [Twilio Console](https://console.twilio.com/)

The same organizational Twilio account may own multiple resources, but use separate Messaging Services and numbers for SocialReply and Albert so routing, signatures, compliance, cost attribution, and rotation remain isolated.

### TWILIO-01 — SocialReply SMS

- [ ] **Status: Create now; verify after deployment — Core**
- Provision or select an SMS-capable number.
- Create a dedicated Messaging Service and attach the number.
- Incoming-message webhook:
  - `https://api.socialreply.ai/webhooks/sms`
- Save for deployment:
  - `TWILIO_ACCOUNT_SID`
  - `TWILIO_AUTH_TOKEN`
  - `TWILIO_MESSAGING_SERVICE_SID`
  - `TWILIO_FROM_NUMBER`
- Leave Twilio's built-in STOP/START/HELP handling enabled unless Twilio Support explicitly changes the account behavior.
- Verify Twilio request signatures after `api.socialreply.ai` has DNS and TLS.

### TWILIO-02 — Albert SMS

- [ ] **Status: Optional**
- Use a separate Albert Messaging Service and number.
- Incoming-message webhook:
  - `https://api.albert.con.fyi/api/v1/webhooks/twilio-sms`
- Store credentials through Albert's encrypted channel settings.

---

## 10. Telegram

Console: [Telegram BotFather](https://t.me/BotFather)

Telegram uses bots rather than a global OAuth developer application.

### TELEGRAM-01 — SocialReply workspace bots

- [ ] **Status: Create per workspace when connecting Telegram**
- Create one bot for each workspace/brand that needs an independent identity.
- Webhook target:
  - `https://api.socialreply.ai/webhooks/telegram`
- Paste the token through SocialReply's workspace channel connection flow. Tokens are encrypted per workspace.
- Do not add bot tokens to Compose. The only global runtime setting is `TELEGRAM_API_BASE_URI=https://api.telegram.org`.

### TELEGRAM-02 — Albert bot

- [ ] **Status: Optional**
- Webhook target:
  - `https://api.albert.con.fyi/api/v1/webhooks/telegram`
- Store the bot token through Albert's encrypted channel settings.

### TELEGRAM-03 — Postiz bot

- [ ] **Status: Optional**
- Save for deployment:
  - `TELEGRAM_TOKEN`
  - `TELEGRAM_BOT_NAME`

---

## 11. Optional publishing providers

Create these only after deciding to expose the matching Postiz or Albert channel. Every Postiz OAuth callback uses the dedicated Postiz application and must not reuse another product's credentials.

### X

Console: [X Developer Portal](https://developer.x.com/en/portal/dashboard)

- [ ] Postiz X application
  - Callback: `https://post.con.fyi/integrations/social/x`
  - Save: `X_API_KEY`, `X_API_SECRET`
- [ ] Albert X application
  - Webhook: `https://api.albert.con.fyi/api/v1/webhooks/twitter`
  - Store through Albert channel settings.

### Reddit

Console: [Reddit app preferences](https://www.reddit.com/prefs/apps)

- [ ] Postiz Reddit web application
  - Callback: `https://post.con.fyi/integrations/social/reddit`
  - Save: `REDDIT_CLIENT_ID`, `REDDIT_CLIENT_SECRET`

### Pinterest

Console: [Pinterest Developers — Apps](https://developers.pinterest.com/apps/)

- [ ] Postiz Pinterest application
  - Callback: `https://post.con.fyi/integrations/social/pinterest`
  - Save: `PINTEREST_CLIENT_ID`, `PINTEREST_CLIENT_SECRET`

### Discord

Console: [Discord Developer Portal](https://discord.com/developers/applications)

- [ ] Postiz Discord application and bot
  - Callback: `https://post.con.fyi/integrations/social/discord`
  - Save: `DISCORD_CLIENT_ID`, `DISCORD_CLIENT_SECRET`, `DISCORD_BOT_TOKEN_ID`

### Mastodon

- [ ] Register a Postiz application against the exact Mastodon instance that will be connected.
  - Callback: `https://post.con.fyi/integrations/social/mastodon`
  - Save: `MASTODON_URL`, `MASTODON_CLIENT_ID`, `MASTODON_CLIENT_SECRET`

### Dribbble

Console: [Dribbble Applications](https://dribbble.com/account/applications)

- [ ] Postiz Dribbble application
  - Callback: `https://post.con.fyi/integrations/social/dribbble`
  - Save: `DRIBBBLE_CLIENT_ID`, `DRIBBBLE_CLIENT_SECRET`

### Farcaster through Neynar

Console: [Neynar Developer Portal](https://dev.neynar.com/)

- [ ] Postiz Neynar application/login configuration
  - Save: `NEYNAR_CLIENT_ID`, `NEYNAR_SECRET_KEY`, `NEYNAR_LOGIN_URL`

### MeWe

- [ ] Postiz MeWe application
  - Callback: `https://post.con.fyi/integrations/social/mewe`
  - Save: `MEWE_HOST`, `MEWE_APP_ID`, `MEWE_API_KEY`

### Twitch

Console: [Twitch Developer Console](https://dev.twitch.tv/console/apps)

- [ ] Postiz Twitch application
  - Callback: `https://post.con.fyi/integrations/social/twitch`
  - Save: `TWITCH_CLIENT_ID`, `TWITCH_CLIENT_SECRET`

### Kick

Console: [Kick Developer](https://dev.kick.com/)

- [ ] Postiz Kick application
  - Callback: `https://post.con.fyi/integrations/social/kick`
  - Save: `KICK_CLIENT_ID`, `KICK_SECRET`

### VK

Console: [VK applications](https://id.vk.com/about/business/go/apps)

- [ ] Postiz VK application
  - Callback: `https://post.con.fyi/integrations/social/vk`
  - Save: `VK_ID`

### Whop

Console: [Whop Developer Dashboard](https://whop.com/dashboard/developer/)

- [ ] Postiz Whop application
  - Callback: `https://post.con.fyi/integrations/social/whop`
  - Save: `WHOP_CLIENT_ID`

### LINE

Console: [LINE Developers Console](https://developers.line.biz/console/)

- [ ] Albert LINE Messaging API channel
  - Webhook: `https://api.albert.con.fyi/api/v1/webhooks/line`
  - Store credentials through Albert channel settings.

## Postiz connectors that do not need a global developer app

Do not create a speculative global application for these connectors. Their account URL, token, password, API key, cookie/extension data, or relay identity is supplied when the channel is connected:

- Bluesky
- Nostr
- Lemmy
- Medium
- Dev.to
- Hashnode
- WordPress
- Listmonk
- Moltbook
- Skool

Tumblr is not exposed by the pinned Postiz v1.47.0 runtime. Do not create or inject Tumblr credentials until a separately approved Postiz upgrade is tested and deployed.

---

## 12. n8n and Buzz

### N8N-01 — Applications required by active workflows

- [ ] Run a redacted inventory of active production workflow node and credential types first.
- Create only provider applications actually referenced by active workflows.
- Generic OAuth2 callback:
  - `https://workflow.con.fyi/rest/oauth2-credential/callback`
- Store resulting credentials in n8n's encrypted credential store, not Compose and not Git.
- Do not create every application that n8n theoretically supports.

### BUZZ-01 — Nostr owner and relay identity

- [ ] No third-party provider account is required.
- Verify and back up:
  - `RELAY_OWNER_PUBKEY`
  - `BUZZ_RELAY_PRIVATE_KEY`
- The public key is the Buzz owner identity. The relay private key is signing material and must remain in the deployment secret store.

---

## Deployments requiring no social provider application

The source audit found no application to create for the current social scope of:

- AgentsHQ
- Togglebox
- Ploon
- Open Growth Group website
- OpenPay
- Twenty core deployment

Twenty's optional Google/Microsoft email and calendar integrations and generic Slack logging hooks are outside this social-channel setup checklist.

## Final handoff checklist

- [ ] Every Core entry has an owner and a provider-side status.
- [ ] Existing Postiz applications were updated instead of duplicated.
- [ ] No Meta, Slack, TikTok, Google, Apple, or GitHub credential was shared across a forbidden boundary.
- [ ] Every callback and webhook exactly matches this document.
- [ ] SocialReply DNS points `socialreply.ai`, `api.socialreply.ai`, and `ws.socialreply.ai` to the production deployment and TLS is valid before webhook verification.
- [ ] `api.clavinci.com` has working DNS and TLS before Clavinci OAuth testing.
- [ ] Secrets exist only in the provider console and deployment secret store.
- [ ] Provider review, verification, Live mode, scope approval, token expiry, and renewal dates are recorded.
- [ ] Each enabled connector completes an authorization test and one safe read/write or webhook smoke test appropriate to its capability.
