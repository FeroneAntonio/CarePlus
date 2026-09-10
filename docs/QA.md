# CarePlus verification checklist

## Automated checks

- Parse every asset catalog `Contents.json` and verify referenced files exist.
- Parse the app Info.plist.
- Parse the complete PostgreSQL migration.
- Build the shared `Care+` scheme for a generic iOS Simulator in GitHub Actions.

## Two-account acceptance test

1. Create a patient account and a caregiver account with different email addresses.
2. Confirm both emails when Supabase email confirmation is enabled.
3. On the patient account, choose **Patient** and enter the caregiver email.
4. Confirm that Account shows the care connection as pending and chat is unavailable.
5. On the caregiver account, choose **Caregiver** and enter the patient email.
6. Reopen Account on both devices and confirm the link is active.
7. Send a message in both directions and confirm ordering and persistence after relaunch.
8. Create, complete and delete a task from each account. Confirm the same state on the other account.
9. Create and delete a diary entry. Confirm it does not reappear after sync.
10. Confirm contacts and SOS selection from one account do not appear in the other account.

## Device-only checks

- Record and replay a voice note after terminating and reopening the app.
- Pick a photo and a video for a diary entry and verify both remain available after relaunch.
- Place a call from a physical iPhone and verify the call log is updated.
- Check VoiceOver labels, Dynamic Type, keyboard avoidance and light/dark appearance.

## Known configuration work

- Run the Supabase migration before testing shared data or chat.
- Configure Apple and Google as Supabase auth providers before enabling those buttons.
- Audio and video files are currently device-local; moving them to a private Supabase Storage bucket is a future enhancement.
