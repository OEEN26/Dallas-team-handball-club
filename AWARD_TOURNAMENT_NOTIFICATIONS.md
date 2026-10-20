# Tournament awards and award notifications

In **Admin Awards**, choose an award, switch **Give award to** to **Tournament participants**, and select a completed tournament. The preview uses its saved final participant roster, including linked guests. Confirm the bulk action to grant the award to eligible participants. Already active grants are skipped; revoked awards are visibly marked for reaward. A roster change invalidates the previous preview. Existing grant triggers retain per-player award history.

Unlinked names and unavailable profiles are listed but are not awarded. Use **Review / link final roster**, link their profiles, refresh the preview, and run the batch again. Existing recipients are skipped automatically. Historical participation awards do not require current season activation and do not activate registrations.

Each new custom award grant or reaward creates a private inbox notification. It goes to the linked player's account, or the linked guardian for a youth player. A historical award granted before account linking gets a notice when the account is linked. Repeated bulk actions do not create duplicate awards or notifications. No old awards were backfilled or assigned as part of deployment.

The header bell and **Notifications** page show unread notices. Notices link to the recipient's award/profile; youth awards are also visible on family player cards. Device alerts use the existing reminder preference and browser permission, and work while the app is open. This change does not add background web-push, email, or SMS delivery.

Database setup: `tournament-awards.sql`, then `award-notifications.sql` (already applied to the connected club project).

Tests: `python verify.py`; run `tournament-awards.test.sql` and `award-notifications.test.sql` through an admin database connection. SQL fixtures end in ROLLBACK and leave no users, participants, awards, or notifications behind. Tests cover linked guests, unlinked participants, stale previews, archived awards, non-admin denial, retry/history behavior, private recipients, guardians, mark-read, reawards, and late account linking.
