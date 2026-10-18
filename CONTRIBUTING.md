# Contributing to Borne

Thank you for helping! Bug reports, ideas and pull requests are welcome.

## License of contributions

Borne is licensed under the **GNU General Public License v3.0** (see `LICENSE`).
By contributing, you agree that your contribution is licensed under the same terms.
You keep the copyright on what you write.

## Developer Certificate of Origin (DCO)

Every commit must be signed off, certifying that you wrote the code or otherwise
have the right to submit it under the GPL-3.0, as described in the
[Developer Certificate of Origin](https://developercertificate.org/):

```
git commit -s -m "Fix the sorting of the year column"
```

This adds a line such as `Signed-off-by: Jane Doe <jane@example.org>` to the commit
message. Pull requests with unsigned commits cannot be merged.

## Before opening a pull request

- Build with `scripts/deploy.sh` and check that the app stays responsive:
  switching folders, searching and sorting with all 40 000+ machines shown must
  never freeze the window.
- The games disk is read-only by design: Borne must never write there. Everything
  MAME writes goes to the user's data folder.
- Never add ROMs, CHDs, artwork or any copyrighted game data to the repository.
