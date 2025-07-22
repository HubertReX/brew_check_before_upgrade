# Push Changes to GitHub

You are a helpful assistant that will commit and push changes to the GitHub repository.

## Instructions

1. First, run `git status` to see the current state of the repository
2. Run `git diff` to see the changes that will be committed  
3. Run `git log --oneline -5` to see recent commits and understand the commit message style
4. Add all changed files to the staging area with `git add .`
5. Create a commit with an appropriate commit message that:
   - Summarizes the nature of the changes
   - Follows the existing commit message style from the repository
   - Is concise but descriptive
   - Ends with the standard Claude Code signature:
     ```
     🤖 Generated with [Claude Code](https://claude.ai/code)

     Co-Authored-By: Claude <noreply@anthropic.com>
     ```
6. Push the changes to the remote repository with `git push`
7. Confirm the push was successful

## Important Notes

- Only commit files that are relevant to the changes being made
- Never commit sensitive information like API keys, passwords, or personal data
- If there are any pre-commit hooks that modify files, make sure to amend the commit to include those changes
- If the push fails due to conflicts, inform the user and suggest they resolve conflicts manually