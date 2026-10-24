# Executive Summary

## Where we were and where we are now

VulnTracker stores security scan results, so it holds sensitive information about our own weak spots. When I started, it was not safe to hold that kind of data. A stranger could have logged in as any user without a password, a normal user could read other people's scans, and one search box could have been used to pull out the whole database. Passwords were also written in plain text in the logs, and the key that protects logins was written inside the code.

Those problems are now closed. Logins can no longer be faked, users see only their own scans, the search box can no longer be abused, passwords are no longer logged, and the login key is kept outside the code. The software libraries were updated, and the serious known weaknesses in them are gone. The service now also has a safe way to be deployed: it runs with few permissions, takes its secret from a secrets manager, and accepts traffic only from where it should.

I also added the new feature to share a single scan with an outsider. Links expire after 24 hours, can have a password, and show only that one scan.

In short: before, the app was open to serious attacks, and now the main ones are closed. It is much safer, but it is not ready for production yet.

## The three biggest risks that remain

1. **The old login key is still in our history.** The key that used to be in the code is still visible in the code's history. The app no longer uses it, but it must be treated as stolen and never used again. Removing it from the history needs the team to agree, because it changes the history for everyone.
2. **The server's base software has known weaknesses with no fix yet.** The base system the app runs on has serious known weaknesses, and its maker has not released fixes. I cannot fix them from here. The app runs with minimal permissions so that these are hard to use, but the risk stays until fixes are released.
3. **Shared links can be guessed at without limit.** A shared link with a password can be tried again and again, because nothing stops repeated wrong guesses. The links are hard to guess and expire after 24 hours, which keeps the risk low. I did not add a limit yet, and it should be added before this goes live.

## What I recommend next

1. Replace every secret that was ever in the code, and store them all in the secrets manager.
2. Run the security checks automatically on every change, so a new problem stops the build.
3. Put a limit on wrong password guesses, and tighten which websites may call the API.
4. Check regularly for fixes to the base software and rebuild when they appear.