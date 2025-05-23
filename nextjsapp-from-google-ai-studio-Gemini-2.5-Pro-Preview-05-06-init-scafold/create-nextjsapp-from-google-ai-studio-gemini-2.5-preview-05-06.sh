#!/bin/bash

echo "Creating project structure for nextjs-mongo-redis-app..."

# Create root directory if it doesn't exist
mkdir -p nextjs-mongo-redis-app
cd nextjs-mongo-redis-app

# Create main files in root
touch .env.local .gitignore docker-compose.yml Dockerfile next.config.mjs package.json tsconfig.json postcss.config.js tailwind.config.ts README.md

# Create public directory
mkdir -p public

# Create src directory and subdirectories
mkdir -p src/app/api/companies/[id]
mkdir -p src/app/api/people/[id]
mkdir -p src/app/companies/new
mkdir -p src/app/companies/[id]/edit
mkdir -p src/app/people/new
mkdir -p src/app/people/[id]/edit
mkdir -p src/components/ui
mkdir -p src/lib
mkdir -p src/models
mkdir -p src/services
mkdir -p src/types

# Create files within src/app
touch src/app/layout.tsx
touch src/app/page.tsx
touch src/app/globals.css

# API routes
touch src/app/api/companies/route.ts
touch src/app/api/companies/[id]/route.ts
touch src/app/api/people/route.ts
touch src/app/api/people/[id]/route.ts

# Company pages
touch src/app/companies/page.tsx
touch src/app/companies/new/page.tsx
touch src/app/companies/[id]/edit/page.tsx

# People pages
touch src/app/people/page.tsx
touch src/app/people/new/page.tsx
touch src/app/people/[id]/edit/page.tsx

# Components
touch src/components/ui/button.tsx
touch src/components/ui/input.tsx
touch src/components/ui/label.tsx
touch src/components/ui/textarea.tsx
touch src/components/ui/modal.tsx
touch src/components/CompanyForm.tsx
touch src/components/CompaniesTable.tsx
touch src/components/PersonForm.tsx
touch src/components/PeopleTable.tsx
touch src/components/Navbar.tsx

# Lib
touch src/lib/mongodb.ts
touch src/lib/redis.ts
touch src/lib/utils.ts
touch src/lib/actions.ts

# Models
touch src/models/Company.ts
touch src/models/Person.ts

# Services
touch src/services/cdcService.ts
touch src/services/redisConsumerService.ts

# Types
touch src/types/index.ts

# Create scripts directory and script
mkdir -p ../scripts # If running from outside nextjs-mongo-redis-app
cp ../setup_dev_env.sh ../scripts/setup_dev_env.sh 2>/dev/null || cp setup_dev_env.sh ../scripts/setup_dev_env.sh 2>/dev/null || echo "Move script to scripts folder manually"


echo "Project structure created."
echo "Please populate the files with the provided code."
echo "Remember to run 'npm init -y' or 'pnpm init' and install dependencies."
echo "Initialize Next.js: npx create-next-app@latest . --typescript --tailwind --eslint --app --src-dir --import-alias \"@/*\" (run this inside the 'nextjs-mongo-redis-app' directory AFTER the script, then copy over the generated files)"
echo "It's often easier to initialize Next.js first, then add custom files."

# A note on using this script:
# It's generally better to use `create-next-app` first to get all the Next.js boilerplate
# and then add the custom files and directories. This script is more for quickly
# scaffolding the *additional* structure.

# Example: Populate .gitignore
cat << EOF > .gitignore
# See https://help.github.com/articles/ignoring-files/ for more about ignoring files.

# Dependencies
/node_modules
/.pnp
.pnp.js

# Testing
/coverage

# Next.js
/.next/
/out/

# Production
/build

# Misc
.DS_Store
*.pem

# Node-specific
npm-debug.log*
yarn-debug.log*
yarn-error.log*
pnpm-debug.log*

# Local Env Files
.env*.local
.env

# IDE / Editor
.vscode/
.idea/
*.swp
*~
EOF

# Example: Populate package.json (very basic, Next.js init will be better)
cat << EOF > package.json
{
  "name": "nextjs-mongo-redis-app",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint"
  },
  "dependencies": {
    "@heroicons/react": "^2.1.1",
    "clsx": "^2.1.0",
    "ioredis": "^5.3.2",
    "mongoose": "^8.2.0",
    "next": "14.1.0",
    "react": "^18",
    "react-dom": "^18",
    "react-hook-form": "^7.51.0",
    "tailwind-merge": "^2.2.1",
    "zod": "^3.22.4"
  },
  "devDependencies": {
    "@types/mongoose": "^5.11.97",
    "@types/node": "^20",
    "@types/react": "^18",
    "@types/react-dom": "^18",
    "autoprefixer": "^10.0.1",
    "eslint": "^8",
    "eslint-config-next": "14.1.0",
    "postcss": "^8",
    "tailwindcss": "^3.3.0",
    "typescript": "^5"
  }
}
EOF

# Basic tailwind.config.ts
cat << EOF > tailwind.config.ts
import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./src/pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/components/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/app/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      backgroundImage: {
        "gradient-radial": "radial-gradient(var(--tw-gradient-stops))",
        "gradient-conic":
          "conic-gradient(from 180deg at 50% 50%, var(--tw-gradient-stops))",
      },
    },
  },
  plugins: [],
};
export default config;
EOF

# Basic postcss.config.js
cat << EOF > postcss.config.js
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
EOF

# Basic tsconfig.json (Next.js init will be better)
cat << EOF > tsconfig.json
{
  "compilerOptions": {
    "target": "es5",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [
      {
        "name": "next"
      }
    ],
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts", "src/lib/mongodb.js"],
  "exclude": ["node_modules"]
}
EOF

# Basic README.md
cat << EOF > README.md
# Next.js, MongoDB, and Redis Fullstack App

This application demonstrates CRUD operations for 'People' and 'Companies' collections in MongoDB,
with change data capture to a Redis stream, and a Redis stream consumer.

## Setup

1.  Ensure Docker and Docker Compose are installed.
2.  Create a \`.env.local\` file from \`.env.example\` (if provided) or set up environment variables as per \`docker-compose.yml\`.
3.  Run \`docker-compose up --build -d\`.
4.  Access the app at \`http://localhost:3000\`.

## Features

-   CRUD for People
-   CRUD for Companies
-   MongoDB Change Data Capture to Redis Stream (\`la:people:changes\`)
-   Redis Stream Consumer for \`la:people:sync:request\`

## Tech Stack

-   Next.js (App Router)
-   TypeScript
-   MongoDB & Mongoose
-   Redis & ioredis
-   Tailwind CSS
-   Docker
EOF

echo "Basic files (.gitignore, package.json, tailwind.config.ts, postcss.config.js, tsconfig.json, README.md) populated."
echo "NOTE: For package.json and tsconfig.json, it's highly recommended to let 'create-next-app' generate them initially."
echo "You can run 'npx create-next-app@latest . --typescript --tailwind --eslint --app --src-dir --import-alias \"@/*\"' "
echo "inside the 'nextjs-mongo-redis-app' directory, then merge or replace files as needed."
