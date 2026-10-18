# Youth and family registration

- `signup.html` asks for the participant birth date before account details. Under-18 registration asks an adult parent or guardian to create their own account.
- `youth-registration.html` lets a verified guardian account add multiple children. A parent who is also a player keeps their adult player dashboard and uses **Youth & Family** in the menu.
- Children are stored as players in the **Youth** group, with no child login required. Their guardian details and birth date are private in `youth_registrations`.
- Each child has separate waiver and player-agreement links. Signatures are bound to the recorded birth date, verified guardian email, and guardian name. Emergency and medical information remains in the signed packet. Media consent is a separate optional choice.
- **Admin menu → Youth Players** shows missing guardian/forms, packets ready for review, and approvals. Staff must review the packet before activation; setting an Active status directly does not bypass this check.
- For existing minors, staff generate a one-use guardian invitation for a specific email. Links expire after seven days; generating a new link invalidates older unused links. Staff copy and share the link themselves; no invitation email is sent automatically.
- Existing linked guardian changes and birth-date corrections require club management. Guardians cannot change the child's birth date through an adult profile.
- Youth rows are omitted from other users' player directories, bios, gallery rows, and tournament roster results. The guardian and club staff retain permitted access. The system verifies email ownership and records the guardian's adult/legal-guardian declaration; it does not independently establish legal guardianship.

## Database setup

Apply `youth-registration.sql`, then `youth-projection-permissions.sql`. Both have already been applied to the connected club database. The projections use security-invoker views over narrow, authenticated projection functions in the non-exposed `youth_internal` schema.

## Checks

- `node youth-registration.test.js`: age boundaries, leap dates and invalid dates.
- `python verify-youth.py`: JavaScript syntax, duplicate HTML IDs and form element references.
- Execute `youth-registration.test.sql` and `youth-invitations.test.sql` through a database-admin connection. They use temporary fixtures inside transactions ending in ROLLBACK: multi-child ownership, unrelated-account denial, verified email, guardian declarations, DOB spoofing, activation checks, media decline, invitation binding and reuse protection. They leave no accounts or player records behind.
