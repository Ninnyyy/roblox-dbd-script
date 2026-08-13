# Setup Instructions

## Prerequisites
- A Roblox executor (Synapse X, Script-Ware, etc.)
- A GitHub account (to host the files)
- Git or GitHub Desktop (optional but helpful)

---

## Step 1: Create a GitHub Repository

1. Go to https://github.com/new
2. Create a new repository named `roblox-dbd-script`
3. Make sure it's **PUBLIC** (important for raw.githubusercontent.com access)
4. Initialize with a README (optional)

---

## Step 2: Upload Files to GitHub

### Option A: Git Command Line
```bash
cd "path/to/roblox dbd script"
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/YOUR-USERNAME/roblox-dbd-script.git
git push -u origin main
```

### Option B: GitHub Desktop
1. Go to File > Add Local Repository
2. Select your project folder
3. Publish the repository
4. Make sure the branch is named `main`

### Option C: Manual Upload
1. Go to https://github.com/YOUR-USERNAME/roblox-dbd-script
2. Click "Add file" > "Upload files"
3. Drag and drop all files from your local folder
4. Commit changes

---

## Step 3: Update the URLs (if needed)

If your GitHub username is different from `Ninnyyy`, update these files:

**File: main.lua**
```lua
local BASE_URL =
    "https://raw.githubusercontent.com/YOUR-USERNAME/roblox-dbd-script/main/"
```

**File: src/core/Init.lua**
```lua
BaseURL =
    "https://raw.githubusercontent.com/YOUR-USERNAME/roblox-dbd-script/main/",
```

---

## Step 4: Test the Script

In your Roblox executor, run:
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR-USERNAME/roblox-dbd-script/main/main.lua"))()
```

Replace `YOUR-USERNAME` with your actual GitHub username.

---

## Troubleshooting

### "HTTP request failed"
- Repository doesn't exist or is private
- Username in URL is wrong
- GitHub is experiencing issues

### "Empty source returned"
- File doesn't exist in the repository
- File path is incorrect
- Repository is private

### Script loads but menu doesn't appear
- Toggle with RIGHT SHIFT
- Check the console for errors
- Make sure all files are in the correct folder structure

### "Module returned nil"
- A module file is empty or has syntax errors
- Check the file exists on GitHub with the correct name (case-sensitive)

---

## Verify Files Are Online

You can manually test if files are accessible:
```
https://raw.githubusercontent.com/YOUR-USERNAME/roblox-dbd-script/main/main.lua
https://raw.githubusercontent.com/YOUR-USERNAME/roblox-dbd-script/main/src/core/Init.lua
https://raw.githubusercontent.com/YOUR-USERNAME/roblox-dbd-script/main/src/core/Features/Camera.lua
```

Open these in a browser - if you see the file contents, they're accessible.

---

## Quick Reference

- **Toggle Menu:** RIGHT SHIFT
- **Save Config:** In Misc tab > Save Config button
- **Load Config:** In Misc tab > Load Config button
- **Switch Theme:** Visuals tab > Theme dropdown
