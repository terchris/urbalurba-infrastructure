# Urbalurba API Project - Quick Start Template

🚀 **Get your Urbalurba API project running in 5 minutes!**

## 🎯 For External Consultants

This template provides everything you need to build an Urbalurba API following our **API-First** approach. You don't need to know API-First development - just follow these steps!

## 📋 Prerequisites

Before starting, make sure you have:
- ✅ .NET 8 SDK installed
- ✅ Git installed  
- ✅ Your favorite code editor (VS Code, Visual Studio, etc.)

## 🚀 Quick Start (5 Steps)

### Step 1: Clone This Template
```bash
# Replace 'my-project-name' with your actual project name
git clone [TEMPLATE-REPO-URL] my-project-name
cd my-project-name
```

### Step 2: Run One-Command Setup
```bash
# This installs tools and pulls Urbalurba shared schemas
./tools/setup.ps1
```

### Step 3: Design Your API
```bash
# Edit your API specification using shared Urbalurba schemas
code api/specs/my-api-v1.yaml
```

**📖 IMPORTANT:** Always use the shared schemas! See `shared-schemas/examples/how-to-reference.yaml` for examples.

### Step 4: Generate & Validate
```bash
# Validate your API specification
./tools/validate.ps1

# Generate server and client code
./tools/generate.ps1
```

### Step 5: Implement Your Logic
```bash
# Implement business logic in the generated controllers
code api/server/src/Controllers/
```

## 📁 Project Structure

```
my-project/
├── README.md                   # This file
├── .gitmodules                 # Git submodule configuration
├── shared-schemas/             # Urbalurba shared schemas (READ-ONLY)
│   ├── fields/v1/              # Individual field types
│   ├── entities/v1/            # Complete business entities  
│   └── examples/               # Usage examples
├── api/
│   ├── specs/
│   │   └── my-api-v1.yaml      # YOUR API specification
│   ├── server/
│   │   ├── nswag-server.json   # Server generation config
│   │   └── src/                # Generated server code goes here
│   └── client/
│       ├── nswag-client.json   # Client generation config
│       └── generated/          # Generated client code goes here
├── tools/
│   ├── setup.ps1               # One-time setup script
│   ├── validate.ps1            # Validate your API spec
│   ├── generate.ps1            # Generate server & client code
│   └── test.ps1                # Run tests
└── docs/
    ├── GETTING-STARTED.md      # Detailed getting started guide
    ├── EXAMPLES.md             # More examples
    └── TROUBLESHOOTING.md      # Common problems & solutions
```

## ⚡ Daily Development Workflow

```bash
# 1. Edit your API specification
code api/specs/my-api-v1.yaml

# 2. Validate changes
./tools/validate.ps1

# 3. Generate code when ready
./tools/generate.ps1

# 4. Implement business logic
code api/server/src/Controllers/

# 5. Test your changes
./tools/test.ps1

# 6. Commit your work (generated code is automatically ignored)
git add .
git commit -m "Implemented feature X"
```

## 🚨 Rules for Success

### ✅ DO:
- ✅ Use shared schemas from `shared-schemas/` folder
- ✅ Follow examples in `shared-schemas/examples/`
- ✅ Run `./tools/validate.ps1` before committing
- ✅ Ask Urbalurba team before creating new field types
- ✅ Read the documentation in `docs/` folder

### ❌ DON'T:
- ❌ Edit anything in `shared-schemas/` folder (it's READ-ONLY)
- ❌ Create your own versions of existing types
- ❌ Skip validation steps
- ❌ Commit generated code (it's auto-ignored)
- ❌ Hardcode values that should be configurable

## 📞 Need Help?

1. **First:** Check `docs/TROUBLESHOOTING.md`
2. **Second:** Look at `shared-schemas/examples/how-to-reference.yaml`
3. **Still stuck?** Contact Urbalurba API Team:
   - 📧 Email: api-team@urbalurba.no
   - 💬 Teams: Urbalurba API Support

## 🎯 What You'll Build

Following this template, you'll create:
- 📋 **OpenAPI specification** using Urbalurba standards
- 🖥️ **ASP.NET Core server** with generated controllers
- 📱 **C# client library** for consuming your API
- ✅ **Automated validation** to prevent mistakes
- 📖 **Auto-generated documentation**

## ⭐ Pro Tips

💡 **Start Simple:** Begin with just 1-2 endpoints, then expand  
💡 **Use Examples:** Copy patterns from `shared-schemas/examples/`  
💡 **Validate Often:** Run `./tools/validate.ps1` frequently  
💡 **Ask Questions:** The Urbalurba team is here to help!

---

**🎉 Happy coding! You're building APIs the Urbalurba way!**
