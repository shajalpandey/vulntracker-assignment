# Executive Summary

## Where we were and where we are now

VulnTracker stores security scan results, so it holds sensitive information about our own weak spots. When I started, it was not safe to hold that kind of data. A stranger could have logged in as any user without a password, a normal user could read other people's scans, and one search box could have been used to pull out the whole database. Passwords were also written in plain text in the logs, and the key that protects logins was written inside the code.

Those problems are now closed. Logins can no longer be faked, users see only their own scans, the search box can no longer be abused, passwords are no longer logged, and the login key is kept outside the code. The software libraries were updated, and the serious known weaknesses in them are gone. The service now also has a safe way to be deployed: it runs with few permissions, takes its secret from a secrets manager, and accepts traffic only from where it should.

I also added the new feature to share a single scan with an outsider. Links expire after 24 hours, can have a password, and show only that one scan.

In short: before, the app was open to serious attacks, and now the main ones are closed. It is much safer, but it is not ready for production yet.

## How I checked
 
I used automatic scans and also read the code myself. The scans looked at five things: the source code, the software libraries the app depends on, the packaged app (the container image), the deployment settings, and the code's history for passwords and keys. Together they found the weak libraries, the unfixed weaknesses in the base software, and two small issues in the deployment settings, one fixed and one accepted.
 
The scans did not find everything. The secrets scan caught two of the keys written in the code, but it missed the one that protects logins, and the other scans found none of them. No scan could see that one user could read another user's data. I found those by reading the code and by testing with two different users. This is why I did both.

## The three biggest risks that remain

1. **The old login key is still in our history.** The key that used to be in the code is still visible in the code's history. The app no longer uses it, but it must be treated as stolen and never used again. Removing it from the history needs the team to agree, because it changes the history for everyone.
2. **The server's base software has known weaknesses with no fix yet.** The base system the app runs on has serious known weaknesses, and its maker has not released fixes. I cannot fix them from here. The app runs with minimal permissions so that these are hard to use, but the risk stays until fixes are released.
3. **Shared links can be guessed at without limit.** A shared link with a password can be tried again and again, because nothing stops repeated wrong guesses.
4. **CI actions use version tags and not fixed commits.** Actions are referenced as `@v4` and `@v5`. A tag can be moved, so the code behind it can change.

## What I recommend next

1. Replace every secret that was ever in the code, and store them all in the secrets manager.
2. Run the security checks automatically on every change, so a new problem stops the build.
3. Put a limit on wrong password guesses, and tighten which websites may call the API.
4. Check regularly for fixes to the base software and rebuild when they appear.
5. The verion tags can be replaced by commit sha in ci actions. This can be looked into and helps enhance security posture of ci pipeline.