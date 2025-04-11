# Spectrum 25 App Documentation

## Project Submission Deadline Management

The Spectrum 25 app includes a feature to automatically close the project submission portal at a specific time. This ensures fair competition by enforcing the same deadline for all participants.

### How the Deadline System Works

1. The system uses a Firestore collection called `timer` with a document named `projectSubmission` that contains a `deadline` timestamp field.
2. When the current time passes this deadline, the submission form is automatically disabled across all devices.
3. Users are shown a clear message that submissions are closed when they attempt to access the submission page after the deadline.
4. The deadline is checked in real-time through a combination of periodic checks and Firestore listeners, ensuring timely enforcement.

### Setting the Deadline (Admin Only)

1. Log in to the app using Organizing Committee credentials.
2. Navigate to the "Settings" tab in the OC Panel.
3. Tap on "Submission Deadline" to open the deadline manager.
4. From here, you can:
   - View the current deadline
   - Change the date and time for the deadline
   - See a preview of the new deadline before saving
   - Save the new deadline

### Important Notes

- Changes to the deadline take effect immediately for all users.
- If a user is in the middle of filling out a submission form when the deadline passes, they will be notified that submissions are closed when they attempt to submit.
- If you need to extend a deadline, simply set a new deadline in the future.
- If you need to close submissions immediately, set the deadline to the current time or a time in the past.
- The deadline manager UI includes a status indicator showing whether submissions are currently open or closed.

### Firestore Database Structure

The deadline is stored in the following location:

```
Collection: timer
Document: projectSubmission
Fields:
  - deadline: Timestamp - The date and time when submissions will close
  - updatedAt: Timestamp - When the deadline was last updated
```

### User Experience

When the deadline passes:
1. The submission form is replaced with a message indicating that submissions are closed.
2. Users who have already submitted will still be able to view their submissions.
3. A banner will be displayed showing when the submission period ended.

### How to Disable the Deadline

If you need to remove the deadline completely and allow submissions at any time:
1. Delete the `projectSubmission` document from the `timer` collection in Firestore.
2. This will allow submissions until a new deadline is set.

### Troubleshooting

If users report issues with the deadline feature:
1. Check that their device time is set correctly - the app uses the local device time to compare with the server deadline.
2. Verify that the `timer/projectSubmission` document exists in Firestore with a valid deadline field.
3. If needed, set a new deadline that's slightly in the future to immediately re-enable submissions.

## Team Names Management

The app uses a Firestore collection to store and verify approved team names during registration, replacing the previous CSV-based approach.

### How the Team Names System Works

1. Approved team names are stored in a Firestore collection called `teamNames`.
2. When a user attempts to register a team, the app checks if the team name exists in this collection.
3. Only teams with names that match entries in the collection can proceed with registration.
4. This provides a dynamic, database-driven approach to team name validation.

### Managing Team Names (Admin Only)

1. Log in to the app using Organizing Committee credentials.
2. Navigate to the "Settings" tab in the OC Panel.
3. Tap on "Team Names" to open the team names manager.
4. From here, you can:
   - View all currently approved team names
   - Add new team names individually
   - Import multiple team names from text (one name per line)
   - Search for specific team names
   - Delete team names that are no longer needed

### Firestore Database Structure

Team names are stored in the following location:

```
Collection: teamNames
Documents: (auto-generated IDs)
Fields:
  - name: String - The approved team name
  - createdAt: Timestamp - When the team name was added
```

### Importing Team Names

To quickly add multiple teams:
1. Access the Team Names Manager
2. Click on "Import From Text"
3. Paste a list of team names (one per line)
4. Click "Import"

### Case Sensitivity

Team name matching is case-insensitive, so "Team Alpha" will match with "team alpha" during registration. However, the original capitalization is preserved in the database. 