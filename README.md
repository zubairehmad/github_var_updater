## Overview Of The App:
This app will help user to update github variable or secret simply by some taps. Main focus of this app is to gain access token (google access token) by signing in the user and update the github secret by the access token.
## Working Of The App:
- When run for the first time, user will be required to enter github api token, so that the app can connect to user's github account using github rest api.
- Then user can navigate through his repositories on the other page.
- The user can then, select a repo to update secret's value.
- When updating secret value, user will be required to give the app google access token by simple login.
- The app will convert the access token to Base64 format and update the secret by the token.
