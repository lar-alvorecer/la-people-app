#!/bin/bash

# --- Configuration ---
PROJECT_ROOT=$(pwd) # Current directory will be the project root
echo "Creating project structure in: $PROJECT_ROOT"

# --- Create Directories ---
echo "Creating directories..."
mkdir -p app/api/people/[id]
mkdir -p app/api/companies/[id]
mkdir -p app/api/webhooks
mkdir -p app/components
mkdir -p app/people
mkdir -p app/companies
mkdir -p lib/models
mkdir -p services
mkdir -p public
mkdir -p types

echo "Directories created."

# --- Create Files with Content ---

# .env.local
echo "Creating .env.local..."
cat <<EOF > .env.local
MONGODB_URI=mongodb://admin:password@localhost:27017/mydatabase?authSource=admin&replicaSet=rs0
REDIS_URL=redis://localhost:6379

MONGO_INITDB_ROOT_USERNAME=admin
MONGO_INITDB_ROOT_PASSWORD=password
EOF
echo ".env.local created."

# docker-compose.yml
echo "Creating docker-compose.yml..."
cat <<'EOF' > docker-compose.yml
version: '3.8'

services:
  # MongoDB Service
  mongodb:
    image: mongo:8.0 # Latest stable MongoDB image
    container_name: mongodb
    ports:
      - "27017:27017"
    environment:
      MONGO_INITDB_ROOT_USERNAME: ${MONGO_INITDB_ROOT_USERNAME}
      MONGO_INITDB_ROOT_PASSWORD: ${MONGO_INITDB_ROOT_PASSWORD}
      # Required for Change Streams
      MONGO_REPLICA_SET_NAME: rs0
    volumes:
      - mongo_data:/data/db
      - ./mongo-init.js:/docker-entrypoint-initdb.d/mongo-init.js:ro # For replica set initiation
    command: ["mongod", "--replSet", "rs0", "--bind_ip_all"]
    healthcheck: # Healthcheck for replica set initiation
      test: ["CMD", "mongosh", "--eval", "quit(db.adminCommand({ ping: 1 }).ok ? 0 : 2)"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - app-network

  # Redis Service
  redis:
    image: redis:8.0.0-alpine # Latest stable Redis image (alpine is lightweight)
    container_name: redis
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    networks:
      - app-network

  # Next.js Application Service
  nextjs-app:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: nextjs-app
    ports:
      - "3000:3000"
    environment:
      NODE_ENV: development
      MONGODB_URI: mongodb://${MONGO_INITDB_ROOT_USERNAME}:${MONGO_INITDB_ROOT_PASSWORD}@mongodb:27017/mydatabase?authSource=admin&replicaSet=rs0 # Connect to MongoDB via network
      REDIS_URL: redis://redis:6379 # Connect to Redis via network
    depends_on:
      mongodb:
        condition: service_healthy # Wait for MongoDB replica set to be ready
      redis:
        condition: service_healthy
    networks:
      - app-network
    restart: on-failure # Important for ensuring change stream listener starts if app crashes

volumes:
  mongo_data:
  redis_data:

networks:
  app-network:
    driver: bridge
EOF
echo "docker-compose.yml created."

# Dockerfile
echo "Creating Dockerfile..."
cat <<'EOF' > Dockerfile
# Stage 1: Install dependencies and build the Next.js app
FROM node:20-alpine AS builder

WORKDIR /app

COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile

COPY . .

# Ensure that the MongoDB connection utility and change stream setup are bundled
# This needs to be carefully handled with Next.js serverless functions.
# For a "true" long-running change stream listener, a separate service might be better.
# In this example, we assume `setupChangeStreams` is called once on server start (e.g. in `api/init` route or a custom server.js)
RUN yarn build

# Stage 2: Run the Next.js app
FROM node:20-alpine AS runner

WORKDIR /app

# Set production environment
ENV NODE_ENV production

# Copy necessary files from the builder stage
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/public ./public
COPY --from=builder /app/lib ./lib
COPY --from=builder /app/services ./services
COPY --from=builder /app/types ./types
COPY --from=builder /app/app ./app

# Expose the port Next.js runs on
EXPOSE 3000

# Command to run the application
# We'll use a custom script to ensure the change stream listener is initiated.
# This is a simplification; ideally, a separate process or a more robust
# Next.js custom server setup would manage long-running tasks.
CMD ["sh", "-c", "node -r esbuild-register -e 'require(\"./lib/mongodb\").default().then(() => require(\"./lib/db-change-stream\").default()); require(\"./lib/redis-stream-consumer\").default();' & yarn start"]
EOF
echo "Dockerfile created."

# mongo-init.js
echo "Creating mongo-init.js..."
cat <<'EOF' > mongo-init.js
var config = {
    _id: "rs0",
    members: [
        { _id: 0, host: "localhost:27017" } // Using localhost for internal Docker network
    ]
};
rs.initiate(config);
rs.conf();
EOF
echo "mongo-init.js created."

# package.json (Minimal, you'll update this with `yarn add` commands)
echo "Creating package.json..."
cat <<EOF > package.json
{
  "name": "my-fullstack-app",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint"
  },
  "dependencies": {
    "next": "^15.3.0",
    "react": "^18",
    "react-dom": "^18"
  },
  "devDependencies": {
    "typescript": "^5",
    "@types/node": "^20",
    "@types/react": "^18",
    "@types/react-dom": "^18",
    "postcss": "^8",
    "tailwindcss": "^3.4.1",
    "eslint": "^8",
    "eslint-config-next": "15.3.0"
  }
}
EOF
echo "package.json created."

# tsconfig.json (Standard Next.js config)
echo "Creating tsconfig.json..."
cat <<'EOF' > tsconfig.json
{
  "compilerOptions": {
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
      "@/*": ["./*"]
    }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
EOF
echo "tsconfig.json created."

# next-env.d.ts (Next.js specific)
echo "Creating next-env.d.ts..."
cat <<'EOF' > next-env.d.ts
/// <reference types="next" />
/// <reference types="next/image-types/global" />

// NOTE: This file should not be edited
// see https://nextjs.org/docs/basic-features/typescript for more information.
EOF
echo "next-env.d.ts created."

# app/layout.tsx
echo "Creating app/layout.tsx..."
cat <<'EOF' > app/layout.tsx
import './globals.css';
import type { Metadata } from 'next';
import { Inter } from 'next/font/google';
import Link from 'next/link';

const inter = Inter({ subsets: ['latin'] });

export const metadata: Metadata = {
  title: 'Fullstack Next.js App',
  description: 'CRUD, MongoDB, Redis Streams',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className={inter.className}>
        <nav className="bg-gray-800 p-4 text-white">
          <div className="container mx-auto flex justify-between">
            <Link href="/" className="text-xl font-bold">
              Home
            </Link>
            <div className="space-x-4">
              <Link href="/people" className="hover:text-gray-300">
                People
              </Link>
              <Link href="/companies" className="hover:text-gray-300">
                Companies
              </Link>
            </div>
          </div>
        </nav>
        <main className="min-h-screen bg-gray-100 dark:bg-gray-900 text-gray-900 dark:text-gray-100">
          {children}
        </main>
      </body>
    </html>
  );
}
EOF
echo "app/layout.tsx created."

# app/page.tsx
echo "Creating app/page.tsx..."
cat <<'EOF' > app/page.tsx
export default function HomePage() {
  return (
    <div className="container mx-auto p-8 text-center">
      <h1 className="text-4xl font-bold mb-4">Welcome to the Fullstack Next.js App!</h1>
      <p className="text-lg mb-8">
        This application demonstrates CRUD operations with MongoDB, real-time change data capture via MongoDB Change Streams, and event processing using Redis Streams.
      </p>
      <div className="flex justify-center space-x-6">
        <a href="/people" className="bg-blue-500 hover:bg-blue-600 text-white font-bold py-3 px-6 rounded-lg text-lg transition duration-300">
          Manage People
        </a>
        <a href="/companies" className="bg-green-500 hover:bg-green-600 text-white font-bold py-3 px-6 rounded-lg text-lg transition duration-300">
          Manage Companies
        </a>
      </div>
      <p className="mt-12 text-gray-600 dark:text-gray-400">
        Built with Next.js, TypeScript, MongoDB, Redis, and Docker Compose.
      </p>
    </div>
  );
}
EOF
echo "app/page.tsx created."

# app/globals.css (Tailwind CSS boilerplate)
echo "Creating app/globals.css..."
cat <<'EOF' > app/globals.css
@tailwind base;
@tailwind components;
@tailwind utilities;

/* You can add custom global styles here */
body {
  @apply bg-gray-100 text-gray-900 dark:bg-gray-900 dark:text-gray-100;
}
EOF
echo "app/globals.css created."

# app/api/people/route.ts
echo "Creating app/api/people/route.ts..."
cat <<'EOF' > app/api/people/route.ts
import { NextResponse } from 'next/server';
import dbConnect from '@/lib/mongodb';
import Person from '@/lib/models/Person';

export async function GET() {
  await dbConnect();
  try {
    const people = await Person.find({});
    return NextResponse.json(people, { status: 200 });
  } catch (error) {
    console.error('Error fetching people:', error);
    return NextResponse.json({ message: 'Error fetching people', error: (error as Error).message }, { status: 500 });
  }
}

export async function POST(req: Request) {
  await dbConnect();
  try {
    const body = await req.json();
    // Mongoose will validate against the schema
    const newPerson = await Person.create(body);
    return NextResponse.json(newPerson, { status: 201 });
  } catch (error) {
    console.error('Error creating person:', error);
    return NextResponse.json({ message: 'Error creating person', error: (error as Error).message }, { status: 500 });
  }
}
EOF
echo "app/api/people/route.ts created."

# app/api/people/[id]/route.ts
echo "Creating app/api/people/[id]/route.ts..."
cat <<'EOF' > app/api/people/[id]/route.ts
import { NextResponse } from 'next/server';
import dbConnect from '@/lib/mongodb';
import Person from '@/lib/models/Person';

export async function GET(req: Request, { params }: { params: { id: string } }) {
  await dbConnect();
  const { id } = params;
  try {
    const person = await Person.findById(id);
    if (!person) {
      return NextResponse.json({ message: 'Person not found' }, { status: 404 });
    }
    return NextResponse.json(person, { status: 200 });
  } catch (error) {
    console.error('Error fetching person by ID:', error);
    return NextResponse.json({ message: 'Error fetching person', error: (error as Error).message }, { status: 500 });
  }
}

export async function PUT(req: Request, { params }: { params: { id: string } }) {
  await dbConnect();
  const { id } = params;
  try {
    const body = await req.json();
    // Mongoose will validate against the schema
    const updatedPerson = await Person.findByIdAndUpdate(id, body, { new: true, runValidators: true });
    if (!updatedPerson) {
      return NextResponse.json({ message: 'Person not found' }, { status: 404 });
    }
    return NextResponse.json(updatedPerson, { status: 200 });
  } catch (error) {
    console.error('Error updating person:', error);
    return NextResponse.json({ message: 'Error updating person', error: (error as Error).message }, { status: 500 });
  }
}

export async function DELETE(req: Request, { params }: { params: { id: string } }) {
  await dbConnect();
  const { id } = params;
  try {
    const deletedPerson = await Person.findByIdAndDelete(id);
    if (!deletedPerson) {
      return NextResponse.json({ message: 'Person not found' }, { status: 404 });
    }
    return NextResponse.json({ message: 'Person deleted successfully' }, { status: 200 });
  } catch (error) {
    console.error('Error deleting person:', error);
    return NextResponse.json({ message: 'Error deleting person', error: (error as Error).message }, { status: 500 });
  }
}
EOF
echo "app/api/people/[id]/route.ts created."

# app/api/companies/route.ts
echo "Creating app/api/companies/route.ts..."
cat <<'EOF' > app/api/companies/route.ts
import { NextResponse } from 'next/server';
import dbConnect from '@/lib/mongodb';
import Company from '@/lib/models/Company';

export async function GET() {
  await dbConnect();
  try {
    const companies = await Company.find({});
    return NextResponse.json(companies, { status: 200 });
  } catch (error) {
    console.error('Error fetching companies:', error);
    return NextResponse.json({ message: 'Error fetching companies', error: (error as Error).message }, { status: 500 });
  }
}

export async function POST(req: Request) {
  await dbConnect();
  try {
    const body = await req.json();
    const newCompany = await Company.create(body);
    return NextResponse.json(newCompany, { status: 201 });
  } catch (error) {
    console.error('Error creating company:', error);
    return NextResponse.json({ message: 'Error creating company', error: (error as Error).message }, { status: 500 });
  }
}
EOF
echo "app/api/companies/route.ts created."

# app/api/companies/[id]/route.ts
echo "Creating app/api/companies/[id]/route.ts..."
cat <<'EOF' > app/api/companies/[id]/route.ts
import { NextResponse } from 'next/server';
import dbConnect from '@/lib/mongodb';
import Company from '@/lib/models/Company';

export async function GET(req: Request, { params }: { params: { id: string } }) {
  await dbConnect();
  const { id } = params;
  try {
    const company = await Company.findById(id);
    if (!company) {
      return NextResponse.json({ message: 'Company not found' }, { status: 404 });
    }
    return NextResponse.json(company, { status: 200 });
  } catch (error) {
    console.error('Error fetching company by ID:', error);
    return NextResponse.json({ message: 'Error fetching company', error: (error as Error).message }, { status: 500 });
  }
}

export async function PUT(req: Request, { params }: { params: { id: string } }) {
  await dbConnect();
  const { id } = params;
  try {
    const body = await req.json();
    const updatedCompany = await Company.findByIdAndUpdate(id, body, { new: true, runValidators: true });
    if (!updatedCompany) {
      return NextResponse.json({ message: 'Company not found' }, { status: 404 });
    }
    return NextResponse.json(updatedCompany, { status: 200 });
  } catch (error) {
    console.error('Error updating company:', error);
    return NextResponse.json({ message: 'Error updating company', error: (error as Error).message }, { status: 500 });
  }
}

export async function DELETE(req: Request, { params }: { params: { id: string } }) {
  await dbConnect();
  const { id } = params;
  try {
    const deletedCompany = await Company.findByIdAndDelete(id);
    if (!deletedCompany) {
      return NextResponse.json({ message: 'Company not found' }, { status: 404 });
    }
    return NextResponse.json({ message: 'Company deleted successfully' }, { status: 200 });
  } catch (error) {
    console.error('Error deleting company:', error);
    return NextResponse.json({ message: 'Error deleting company', error: (error as Error).message }, { status: 500 });
  }
}
EOF
echo "app/api/companies/[id]/route.ts created."

# app/api/webhooks/redis-consumer.ts
echo "Creating app/api/webhooks/redis-consumer.ts..."
cat <<'EOF' > app/api/webhooks/redis-consumer.ts
// This is an *illustrative* example for a Next.js API route that *could* initiate a consumer.
// For continuous, reliable stream processing, a separate long-running process is recommended.

import { NextResponse } from 'next/server';
import setupRedisStreamConsumer from '@/lib/redis-stream-consumer';

// This flag ensures the consumer is only started once
let consumerStarted = false;

export async function GET() {
  if (!consumerStarted) {
    console.log('Attempting to start Redis Stream Consumer...');
    // In a real production scenario, this `setupRedisStreamConsumer` should ideally
    // be run in a separate process that is always on, rather than triggered by an HTTP request
    // which might go idle.
    setupRedisStreamConsumer();
    consumerStarted = true;
    return NextResponse.json({ message: 'Redis Stream Consumer initiated (check server logs for status)' }, { status: 200 });
  } else {
    return NextResponse.json({ message: 'Redis Stream Consumer already running' }, { status: 200 });
  }
}

// You might also have a POST request to trigger it or for health checks.
export async function POST() {
  return await GET();
}
EOF
echo "app/api/webhooks/redis-consumer.ts created."

# app/components/DataTable.tsx
echo "Creating app/components/DataTable.tsx..."
cat <<'EOF' > app/components/DataTable.tsx
'use client';

import React from 'react';

interface DataTableProps<T> {
  data: T[];
  columns: { header: string; accessor: keyof T | ((item: T) => React.ReactNode) }[];
  onEdit: (item: T) => void;
  onDelete: (item: T) => void;
}

export function DataTable<T extends { _id: string } | { id: string }>({
  data,
  columns,
  onEdit,
  onDelete,
}: DataTableProps<T>) {
  return (
    <div className="overflow-x-auto relative shadow-md sm:rounded-lg">
      <table className="w-full text-sm text-left text-gray-500 dark:text-gray-400">
        <thead className="text-xs text-gray-700 uppercase bg-gray-50 dark:bg-gray-700 dark:text-gray-400">
          <tr>
            {columns.map((col, index) => (
              <th key={index} scope="col" className="py-3 px-6">
                {col.header}
              </th>
            ))}
            <th scope="col" className="py-3 px-6">
              Actions
            </th>
          </tr>
        </thead>
        <tbody>
          {data.map((item) => (
            <tr key={(item as any)._id || (item as any).id} className="bg-white border-b dark:bg-gray-800 dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-600">
              {columns.map((col, index) => (
                <td key={index} className="py-4 px-6">
                  {typeof col.accessor === 'function' ? col.accessor(item) : (item[col.accessor] as any)}
                </td>
              ))}
              <td className="py-4 px-6 space-x-2">
                <button
                  onClick={() => onEdit(item)}
                  className="font-medium text-blue-600 dark:text-blue-500 hover:underline"
                >
                  Edit
                </button>
                <button
                  onClick={() => onDelete(item)}
                  className="font-medium text-red-600 dark:text-red-500 hover:underline"
                >
                  Delete
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
EOF
echo "app/components/DataTable.tsx created."

# app/components/Modal.tsx
echo "Creating app/components/Modal.tsx..."
cat <<'EOF' > app/components/Modal.tsx
'use client';

import React, { ReactNode } from 'react';

interface ModalProps {
  isOpen: boolean;
  onClose: () => void;
  title: string;
  children: ReactNode;
}

export function Modal({ isOpen, onClose, title, children }: ModalProps) {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50 flex justify-center items-center">
      <div className="relative p-5 border w-96 shadow-lg rounded-md bg-white dark:bg-gray-800 dark:border-gray-700">
        <div className="flex justify-between items-center pb-3">
          <h3 className="text-lg font-semibold text-gray-900 dark:text-white">{title}</h3>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600 dark:hover:text-gray-300">
            <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M6 18L18 6M6 6l12 12"></path>
            </svg>
          </button>
        </div>
        <div className="mt-2 text-gray-700 dark:text-gray-300">
          {children}
        </div>
      </div>
    </div>
  );
}
EOF
echo "app/components/Modal.tsx created."

# app/components/PersonForm.tsx
echo "Creating app/components/PersonForm.tsx..."
cat <<'EOF' > app/components/PersonForm.tsx
'use client';

import React, { useState, useEffect } from 'react';
import { IPerson } from '@/lib/models/Person'; // Import the interface

interface PersonFormProps {
  initialData?: IPerson | null;
  onSubmit: (data: Partial<IPerson>) => void;
  onCancel: () => void;
}

const PersonForm: React.FC<PersonFormProps> = ({ initialData, onSubmit, onCancel }) => {
  const [formData, setFormData] = useState<Partial<IPerson>>({
    firstName: '',
    lastName: '',
    email: '',
    birthDate: '',
    gender: 'Male',
    companyId: undefined,
  });

  useEffect(() => {
    if (initialData) {
      setFormData({
        firstName: initialData.firstName,
        lastName: initialData.lastName,
        email: initialData.email,
        birthDate: initialData.birthDate,
        gender: initialData.gender,
        companyId: initialData.companyId ? initialData.companyId.toString() : undefined, // Convert ObjectId to string
      });
    } else {
      setFormData({
        firstName: '',
        lastName: '',
        email: '',
        birthDate: '',
        gender: 'Male',
        companyId: undefined,
      });
    }
  }, [initialData]);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
    const { name, value } = e.target;
    setFormData((prev) => ({ ...prev, [name]: value }));
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onSubmit(formData);
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div>
        <label htmlFor="firstName" className="block text-sm font-medium text-gray-700 dark:text-gray-300">First Name</label>
        <input
          type="text"
          id="firstName"
          name="firstName"
          value={formData.firstName}
          onChange={handleChange}
          required
          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 dark:bg-gray-700 dark:border-gray-600 dark:text-white"
        />
      </div>
      <div>
        <label htmlFor="lastName" className="block text-sm font-medium text-gray-700 dark:text-gray-300">Last Name</label>
        <input
          type="text"
          id="lastName"
          name="lastName"
          value={formData.lastName}
          onChange={handleChange}
          required
          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 dark:bg-gray-700 dark:border-gray-600 dark:text-white"
        />
      </div>
      <div>
        <label htmlFor="email" className="block text-sm font-medium text-gray-700 dark:text-gray-300">Email</label>
        <input
          type="email"
          id="email"
          name="email"
          value={formData.email}
          onChange={handleChange}
          required
          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 dark:bg-gray-700 dark:border-gray-600 dark:text-white"
        />
      </div>
      <div>
        <label htmlFor="birthDate" className="block text-sm font-medium text-gray-700 dark:text-gray-300">Birth Date (YYYY-MM-DD)</label>
        <input
          type="date"
          id="birthDate"
          name="birthDate"
          value={formData.birthDate}
          onChange={handleChange}
          required
          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 dark:bg-gray-700 dark:border-gray-600 dark:text-white"
        />
      </div>
      <div>
        <label htmlFor="gender" className="block text-sm font-medium text-gray-700 dark:text-gray-300">Gender</label>
        <select
          id="gender"
          name="gender"
          value={formData.gender}
          onChange={handleChange}
          required
          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 dark:bg-gray-700 dark:border-gray-600 dark:text-white"
        >
          <option value="Male">Male</option>
          <option value="Female">Female</option>
          <option value="Other">Other</option>
        </select>
      </div>
      <div>
        <label htmlFor="companyId" className="block text-sm font-medium text-gray-700 dark:text-gray-300">Company ID (Optional)</label>
        <input
          type="text"
          id="companyId"
          name="companyId"
          value={formData.companyId || ''}
          onChange={handleChange}
          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 dark:bg-gray-700 dark:border-gray-600 dark:text-white"
          placeholder="e.g., 60c72b2f9b1e8e001c8e8e8e"
        />
      </div>
      <div className="flex justify-end space-x-2">
        <button
          type="button"
          onClick={onCancel}
          className="px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 dark:bg-gray-600 dark:text-white dark:border-gray-500 dark:hover:bg-gray-700"
        >
          Cancel
        </button>
        <button
          type="submit"
          className="px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
        >
          {initialData ? 'Update' : 'Add'} Person
        </button>
      </div>
    </form>
  );
};

export default PersonForm;
EOF
echo "app/components/PersonForm.tsx created."

# app/components/CompanyForm.tsx
echo "Creating app/components/CompanyForm.tsx..."
cat <<'EOF' > app/components/CompanyForm.tsx
'use client';

import React, { useState, useEffect } from 'react';
import { ICompany } from '@/lib/models/Company'; // Import the interface

interface CompanyFormProps {
  initialData?: ICompany | null;
  onSubmit: (data: Partial<ICompany>) => void;
  onCancel: () => void;
}

const CompanyForm: React.FC<CompanyFormProps> = ({ initialData, onSubmit, onCancel }) => {
  const [formData, setFormData] = useState<Partial<ICompany>>({
    name: '',
    address: '',
    phone: '',
    email: '',
    website: '',
    status: 'Active',
  });

  useEffect(() => {
    if (initialData) {
      setFormData({
        name: initialData.name,
        address: initialData.address,
        phone: initialData.phone,
        email: initialData.email,
        website: initialData.website || '',
        status: initialData.status,
      });
    } else {
      setFormData({
        name: '',
        address: '',
        phone: '',
        email: '',
        website: '',
        status: 'Active',
      });
    }
  }, [initialData]);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
    const { name, value } = e.target;
    setFormData((prev) => ({ ...prev, [name]: value }));
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onSubmit(formData);
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div>
        <label htmlFor="name" className="block text-sm font-medium text-gray-700 dark:text-gray-300">Company Name</label>
        <input
          type="text"
          id="name"
          name="name"
          value={formData.name}
          onChange={handleChange}
          required
          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 dark:bg-gray-700 dark:border-gray-600 dark:text-white"
        />
      </div>
      <div>
        <label htmlFor="address" className="block text-sm font-medium text-gray-700 dark:text-gray-300">Address</label>
        <input
          type="text"
          id="address"
          name="address"
          value={formData.address}
          onChange={handleChange}
          required
          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 dark:bg-gray-700 dark:border-gray-600 dark:text-white"
        />
      </div>
      <div>
        <label htmlFor="phone" className="block text-sm font-medium text-gray-700 dark:text-gray-300">Phone</label>
        <input
          type="tel"
          id="phone"
          name="phone"
          value={formData.phone}
          onChange={handleChange}
          required
          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 dark:bg-gray-700 dark:border-gray-600 dark:text-white"
        />
      </div>
      <div>
        <label htmlFor="email" className="block text-sm font-medium text-gray-700 dark:text-gray-300">Email</label>
        <input
          type="email"
          id="email"
          name="email"
          value={formData.email}
          onChange={handleChange}
          required
          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 dark:bg-gray-700 dark:border-gray-600 dark:text-white"
        />
      </div>
      <div>
        <label htmlFor="website" className="block text-sm font-medium text-gray-700 dark:text-gray-300">Website (Optional)</label>
        <input
          type="url"
          id="website"
          name="website"
          value={formData.website}
          onChange={handleChange}
          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 dark:bg-gray-700 dark:border-gray-600 dark:text-white"
          placeholder="https://example.com"
        />
      </div>
      <div>
        <label htmlFor="status" className="block text-sm font-medium text-gray-700 dark:text-gray-300">Status</label>
        <select
          id="status"
          name="status"
          value={formData.status}
          onChange={handleChange}
          required
          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 dark:bg-gray-700 dark:border-gray-600 dark:text-white"
        >
          <option value="Active">Active</option>
          <option value="Inactive">Inactive</option>
          <option value="Pending">Pending</option>
        </select>
      </div>
      <div className="flex justify-end space-x-2">
        <button
          type="button"
          onClick={onCancel}
          className="px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 dark:bg-gray-600 dark:text-white dark:border-gray-500 dark:hover:bg-gray-700"
        >
          Cancel
        </button>
        <button
          type="submit"
          className="px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
        >
          {initialData ? 'Update' : 'Add'} Company
        </button>
      </div>
    </form>
  );
};

export default CompanyForm;
EOF
echo "app/components/CompanyForm.tsx created."


# app/people/page.tsx
echo "Creating app/people/page.tsx..."
cat <<'EOF' > app/people/page.tsx
'use client';

import React, { useState, useEffect } from 'react';
import { DataTable } from '@/app/components/DataTable';
import { Modal } from '@/app/components/Modal';
import PersonForm from '@/app/components/PersonForm';
import { IPerson } from '@/lib/models/Person'; // Import the updated interface

export default function PeoplePage() {
  const [people, setPeople] = useState<IPerson[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [currentPerson, setCurrentPerson] = useState<IPerson | null>(null);

  const fetchPeople = async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await fetch('/api/people');
      if (!res.ok) {
        throw new Error(`HTTP error! status: ${res.status}`);
      }
      const data: IPerson[] = await res.json();
      setPeople(data);
    } catch (e: any) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchPeople();
  }, []);

  const handleAddEdit = async (personData: Partial<IPerson>) => {
    try {
      const method = currentPerson ? 'PUT' : 'POST';
      const url = currentPerson ? `/api/people/${currentPerson._id}` : '/api/people';
      const res = await fetch(url, {
        method,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(personData),
      });

      if (!res.ok) {
        const errorData = await res.json();
        throw new Error(errorData.message || 'Failed to save person');
      }
      await fetchPeople();
      setIsModalOpen(false);
      setCurrentPerson(null);
    } catch (e: any) {
      // Use a custom message box instead of alert()
      const messageBox = document.createElement('div');
      messageBox.className = 'fixed inset-0 bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded relative m-auto w-1/3 h-1/6 flex items-center justify-center';
      messageBox.setAttribute('role', 'alert');
      messageBox.innerHTML = \`
        <strong class="font-bold">Error!</strong>
        <span class="block sm:inline ml-2">\${e.message}</span>
        <span class="absolute top-0 bottom-0 right-0 px-4 py-3 cursor-pointer" onclick="this.parentElement.remove()">
          <svg class="fill-current h-6 w-6 text-red-500" role="button" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20"><title>Close</title><path d="M14.348 14.849a1.2 1.2 0 0 1-1.697 0L10 11.103l-2.651 3.746a1.2 1.2 0 0 1-1.697-1.697l3.746-2.651-3.746-2.651a1.2 1.2 0 0 1 1.697-1.697L10 8.897l2.651-3.746a1.2 1.2 0 0 1 1.697 1.697L11.103 10l3.746 2.651a1.2 1.2 0 0 1 0 1.698z"/></svg>
        </span>
      \`;
      document.body.appendChild(messageBox);
      setTimeout(() => messageBox.remove(), 5000); // Auto-remove after 5 seconds
    }
  };

  const handleDelete = async (person: IPerson) => {
    // Use a custom confirmation modal instead of confirm()
    const confirmDelete = window.confirm(\`Are you sure you want to delete \${person.firstName} \${person.lastName}?\`);
    if (!confirmDelete) return;

    try {
      const res = await fetch(\`/api/people/\${person._id}\`, { method: 'DELETE' });
      if (!res.ok) {
        const errorData = await res.json();
        throw new Error(errorData.message || 'Failed to delete person');
      }
      await fetchPeople();
    } catch (e: any) {
      // Use a custom message box
      const messageBox = document.createElement('div');
      messageBox.className = 'fixed inset-0 bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded relative m-auto w-1/3 h-1/6 flex items-center justify-center';
      messageBox.setAttribute('role', 'alert');
      messageBox.innerHTML = \`
        <strong class="font-bold">Error!</strong>
        <span class="block sm:inline ml-2">\${e.message}</span>
        <span class="absolute top-0 bottom-0 right-0 px-4 py-3 cursor-pointer" onclick="this.parentElement.remove()">
          <svg class="fill-current h-6 w-6 text-red-500" role="button" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20"><title>Close</title><path d="M14.348 14.849a1.2 1.2 0 0 1-1.697 0L10 11.103l-2.651 3.746a1.2 1.2 0 0 1-1.697-1.697l3.746-2.651-3.746-2.651a1.2 1.2 0 0 1 1.697-1.697L10 8.897l2.651-3.746a1.2 1.2 0 0 1 1.697 1.697L11.103 10l3.746 2.651a1.2 1.2 0 0 1 0 1.698z"/></svg>
        </span>
      \`;
      document.body.appendChild(messageBox);
      setTimeout(() => messageBox.remove(), 5000); // Auto-remove after 5 seconds
    }
  };

  const openAddModal = () => {
    setCurrentPerson(null);
    setIsModalOpen(true);
  };

  const openEditModal = (person: IPerson) => {
    setCurrentPerson(person);
    setIsModalOpen(true);
  };

  const closeFormModal = () => {
    setIsModalOpen(false);
    setCurrentPerson(null);
  };

  if (loading) return <div className="p-4 text-center">Loading people...</div>;
  if (error) return <div className="p-4 text-center text-red-500">Error: {error}</div>;

  return (
    <div className="container mx-auto p-4">
      <h1 className="text-3xl font-bold mb-6 text-center">People Management</h1>
      <div className="mb-4 text-right">
        <button
          onClick={openAddModal}
          className="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
        >
          Add New Person
        </button>
      </div>

      <DataTable<IPerson>
        data={people}
        columns={[
          { header: 'First Name', accessor: 'firstName' },
          { header: 'Last Name', accessor: 'lastName' },
          { header: 'Email', accessor: 'email' },
          { header: 'Birth Date', accessor: 'birthDate' },
          { header: 'Gender', accessor: 'gender' },
          { header: 'Company ID', accessor: (p) => p.companyId?.toString() || 'N/A' },
          { header: 'Created At', accessor: (p) => new Date(p.createdAt).toLocaleDateString() },
          { header: 'Updated At', accessor: (p) => new Date(p.updatedAt).toLocaleDateString() },
        ]}
        onEdit={openEditModal}
        onDelete={handleDelete}
      />

      <Modal isOpen={isModalOpen} onClose={closeFormModal} title={currentPerson ? 'Edit Person' : 'Add New Person'}>
        <PersonForm initialData={currentPerson} onSubmit={handleAddEdit} onCancel={closeFormModal} />
      </Modal>
    </div>
  );
}
EOF
echo "app/people/page.tsx created."

# app/companies/page.tsx
echo "Creating app/companies/page.tsx..."
cat <<'EOF' > app/companies/page.tsx
'use client';

import React, { useState, useEffect } from 'react';
import { DataTable } from '@/app/components/DataTable';
import { Modal } from '@/app/components/Modal';
import CompanyForm from '@/app/components/CompanyForm';
import { ICompany } from '@/lib/models/Company'; // Import the updated interface

export default function CompaniesPage() {
  const [companies, setCompanies] = useState<ICompany[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [currentCompany, setCurrentCompany] = useState<ICompany | null>(null);

  const fetchCompanies = async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await fetch('/api/companies');
      if (!res.ok) {
        throw new Error(`HTTP error! status: ${res.status}`);
      }
      const data: ICompany[] = await res.json();
      setCompanies(data);
    } catch (e: any) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchCompanies();
  }, []);

  const handleAddEdit = async (companyData: Partial<ICompany>) => {
    try {
      const method = currentCompany ? 'PUT' : 'POST';
      const url = currentCompany ? `/api/companies/${currentCompany._id}` : '/api/companies';
      const res = await fetch(url, {
        method,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(companyData),
      });

      if (!res.ok) {
        const errorData = await res.json();
        throw new Error(errorData.message || 'Failed to save company');
      }
      await fetchCompanies();
      setIsModalOpen(false);
      setCurrentCompany(null);
    } catch (e: any) {
      // Use a custom message box instead of alert()
      const messageBox = document.createElement('div');
      messageBox.className = 'fixed inset-0 bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded relative m-auto w-1/3 h-1/6 flex items-center justify-center';
      messageBox.setAttribute('role', 'alert');
      messageBox.innerHTML = \`
        <strong class="font-bold">Error!</strong>
        <span class="block sm:inline ml-2">\${e.message}</span>
        <span class="absolute top-0 bottom-0 right-0 px-4 py-3 cursor-pointer" onclick="this.parentElement.remove()">
          <svg class="fill-current h-6 w-6 text-red-500" role="button" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20"><title>Close</title><path d="M14.348 14.849a1.2 1.2 0 0 1-1.697 0L10 11.103l-2.651 3.746a1.2 1.2 0 0 1-1.697-1.697l3.746-2.651-3.746-2.651a1.2 1.2 0 0 1 1.697-1.697L10 8.897l2.651-3.746a1.2 1.2 0 0 1 1.697 1.697L11.103 10l3.746 2.651a1.2 1.2 0 0 1 0 1.698z"/></svg>
        </span>
      \`;
      document.body.appendChild(messageBox);
      setTimeout(() => messageBox.remove(), 5000); // Auto-remove after 5 seconds
    }
  };

  const handleDelete = async (company: ICompany) => {
    // Use a custom confirmation modal instead of confirm()
    const confirmDelete = window.confirm(\`Are you sure you want to delete \${company.name}?\`);
    if (!confirmDelete) return;

    try {
      const res = await fetch(\`/api/companies/\${company._id}\`, { method: 'DELETE' });
      if (!res.ok) {
        const errorData = await res.json();
        throw new Error(errorData.message || 'Failed to delete company');
      }
      await fetchCompanies();
    } catch (e: any) {
      // Use a custom message box
      const messageBox = document.createElement('div');
      messageBox.className = 'fixed inset-0 bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded relative m-auto w-1/3 h-1/6 flex items-center justify-center';
      messageBox.setAttribute('role', 'alert');
      messageBox.innerHTML = \`
        <strong class="font-bold">Error!</strong>
        <span class="block sm:inline ml-2">\${e.message}</span>
        <span class="absolute top-0 bottom-0 right-0 px-4 py-3 cursor-pointer" onclick="this.parentElement.remove()">
          <svg class="fill-current h-6 w-6 text-red-500" role="button" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20"><title>Close</title><path d="M14.348 14.849a1.2 1.2 0 0 1-1.697 0L10 11.103l-2.651 3.746a1.2 1.2 0 0 1-1.697-1.697l3.746-2.651-3.746-2.651a1.2 1.2 0 0 1 1.697-1.697L10 8.897l2.651-3.746a1.2 1.2 0 0 1 1.697 1.697L11.103 10l3.746 2.651a1.2 1.2 0 0 1 0 1.698z"/></svg>
        </span>
      \`;
      document.body.appendChild(messageBox);
      setTimeout(() => messageBox.remove(), 5000); // Auto-remove after 5 seconds
    }
  };

  const openAddModal = () => {
    setCurrentCompany(null);
    setIsModalOpen(true);
  };

  const openEditModal = (company: ICompany) => {
    setCurrentCompany(company);
    setIsModalOpen(true);
  };

  const closeFormModal = () => {
    setIsModalOpen(false);
    setCurrentCompany(null);
  };

  if (loading) return <div className="p-4 text-center">Loading companies...</div>;
  if (error) return <div className="p-4 text-center text-red-500">Error: {error}</div>;

  return (
    <div className="container mx-auto p-4">
      <h1 className="text-3xl font-bold mb-6 text-center">Companies Management</h1>
      <div className="mb-4 text-right">
        <button
          onClick={openAddModal}
          className="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
        >
          Add New Company
        </button>
      </div>

      <DataTable<ICompany>
        data={companies}
        columns={[
          { header: 'Name', accessor: 'name' },
          { header: 'Address', accessor: 'address' },
          { header: 'Phone', accessor: 'phone' },
          { header: 'Email', accessor: 'email' },
          { header: 'Website', accessor: 'website' },
          { header: 'Status', accessor: 'status' },
          { header: 'Created At', accessor: (c) => new Date(c.createdAt).toLocaleDateString() },
          { header: 'Updated At', accessor: (c) => new Date(c.updatedAt).toLocaleDateString() },
        ]}
        onEdit={openEditModal}
        onDelete={handleDelete}
      />

      <Modal isOpen={isModalOpen} onClose={closeFormModal} title={currentCompany ? 'Edit Company' : 'Add New Company'}>
        <CompanyForm initialData={currentCompany} onSubmit={handleAddEdit} onCancel={closeFormModal} />
      </Modal>
    </div>
  );
}
EOF
echo "app/companies/page.tsx created."


# lib/mongodb.ts
echo "Creating lib/mongodb.ts..."
cat <<'EOF' > lib/mongodb.ts
import mongoose from 'mongoose';

const MONGODB_URI = process.env.MONGODB_URI;

if (!MONGODB_URI) {
  throw new Error('Please define the MONGODB_URI environment variable inside .env.local');
}

let cached = global.mongoose;

if (!cached) {
  cached = global.mongoose = { conn: null, promise: null };
}

async function dbConnect() {
  if (cached.conn) {
    return cached.conn;
  }

  if (!cached.promise) {
    const opts = {
      bufferCommands: false,
    };

    cached.promise = mongoose.connect(MONGODB_URI, opts).then((mongoose) => {
      return mongoose;
    });
  }
  cached.conn = await cached.promise;
  return cached.conn;
}

export default dbConnect;
EOF
echo "lib/mongodb.ts created."

# lib/redis.ts
echo "Creating lib/redis.ts..."
cat <<'EOF' > lib/redis.ts
import Redis from 'ioredis';

const REDIS_URL = process.env.REDIS_URL || 'redis://localhost:6379';

const redis = new Redis(REDIS_URL);

redis.on('connect', () => {
  console.log('Connected to Redis');
});

redis.on('error', (err) => {
  console.error('Redis connection error:', err);
});

export const publishToRedisStream = async (service: string, queue: string, data: any) => {
  try {
    const streamKey = `${service}:${queue}`;
    // XADD streamKey * field1 value1 field2 value2 ...
    // We'll stringify the data as a single field for simplicity
    await redis.xadd(streamKey, '*', 'data', JSON.stringify(data));
    console.log(`Published to Redis Stream "${streamKey}" with data:`, data);
  } catch (error) {
    console.error('Error publishing to Redis Stream:', error);
  }
};

export default redis;
EOF
echo "lib/redis.ts created."

# lib/models/Person.ts
echo "Creating lib/models/Person.ts..."
cat <<'EOF' > lib/models/Person.ts
import mongoose, { Schema, Document } from 'mongoose';

export interface IPerson extends Document {
  firstName: string;
  lastName: string;
  email: string;
  birthDate: string; //<ctrl42>-MM-DD
  gender: 'Male' | 'Female' | 'Other';
  companyId?: mongoose.Types.ObjectId; // Optional link to Company
  createdAt: Date;
  updatedAt: Date;
}

const PersonSchema: Schema = new Schema({
  firstName: { type: String, required: true, minlength: 1 },
  lastName: { type: String, required: true, minlength: 1 },
  email: { type: String, required: true, unique: true, match: /^\S+@\S+\.\S+$/ },
  birthDate: { type: String, required: true, match: /^\d{4}-\d{2}-\d{2}$/ }, //<ctrl42>-MM-DD format
  gender: { type: String, required: true, enum: ['Male', 'Female', 'Other'] },
  companyId: { type: Schema.Types.ObjectId, ref: 'Company', default: null }, // Nullable
}, { timestamps: true }); // Mongoose handles createdAt and updatedAt

const Person = mongoose.models.Person || mongoose.model<IPerson>('Person', PersonSchema);

export default Person;
EOF
echo "lib/models/Person.ts created."

# lib/models/Company.ts
echo "Creating lib/models/Company.ts..."
cat <<'EOF' > lib/models/Company.ts
import mongoose, { Schema, Document } from 'mongoose';

export interface ICompany extends Document {
  name: string;
  address: string;
  phone: string;
  email: string;
  website?: string; // Optional as per schema (not in required list)
  status: 'Active' | 'Inactive' | 'Pending';
  createdAt: Date;
  updatedAt: Date;
}

const CompanySchema: Schema = new Schema({
  name: { type: String, required: true, unique: true, minlength: 1 },
  address: { type: String, required: true, minlength: 1 },
  phone: { type: String, required: true },
  email: { type: String, required: true, match: /^\S+@\S+\.\S+$/ },
  website: { type: String, match: /^(https?|ftp):\/\/[^\s/$.?#].[^\s]*$/i }, // Basic URL validation
  status: { type: String, required: true, enum: ['Active', 'Inactive', 'Pending'] },
}, { timestamps: true }); // Mongoose handles createdAt and updatedAt

const Company = mongoose.models.Company || mongoose.model<ICompany>('Company', CompanySchema);

export default Company;
EOF
echo "lib/models/Company.ts created."

# lib/db-change-stream.ts
echo "Creating lib/db-change-stream.ts..."
cat <<'EOF' > lib/db-change-stream.ts
import mongoose from 'mongoose';
import { publishToRedisStream } from './redis';

const setupChangeStreams = () => {
  if (!mongoose.connection.readyState) {
    console.log('MongoDB not connected, skipping change stream setup.');
    return;
  }

  // Watch for changes on the 'people' collection
  const personChangeStream = mongoose.connection.collection('people').watch();

  personChangeStream.on('change', (change) => {
    const eventData = {
      operationType: change.operationType,
      fullDocument: change.fullDocument, // The document after insert/update
      documentKey: change.documentKey, // _id of the changed document
      updateDescription: (change as any).updateDescription, // For update operations
      ns: change.ns, // Namespace (database.collection)
      clusterTime: change.clusterTime, // Timestamp of the operation
    };
    console.log('Change detected in people:', eventData);
    publishToRedisStream('redis-integration-db', 'la:people:changes', eventData);
  });

  personChangeStream.on('error', (error) => {
    console.error('Error in person change stream:', error);
  });

  console.log('MongoDB Change Stream for "people" collection initialized.');

  // Watch for changes on the 'companies' collection
  const companyChangeStream = mongoose.connection.collection('companies').watch();

  companyChangeStream.on('change', (change) => {
    const eventData = {
      operationType: change.operationType,
      fullDocument: change.fullDocument,
      documentKey: change.documentKey,
      updateDescription: (change as any).updateDescription,
      ns: change.ns,
      clusterTime: change.clusterTime,
    };
    console.log('Change detected in companies:', eventData);
    // You might have a separate stream for companies or a combined one
    publishToRedisStream('redis-integration-db', 'la:companies:changes', eventData);
  });

  companyChangeStream.on('error', (error) => {
    console.error('Error in company change stream:', error);
  });

  console.log('MongoDB Change Stream for "companies" collection initialized.');
};

export default setupChangeStreams;
EOF
echo "lib/db-change-stream.ts created."

# lib/redis-stream-consumer.ts
echo "Creating lib/redis-stream-consumer.ts..."
cat <<'EOF' > lib/redis-stream-consumer.ts
import redis from './redis';
import { processIncomingEvent } from '@/services/event-processor';

const STREAM_KEY = 'la:people:sync:request';
const CONSUMER_GROUP = 'la:people:sync:group';
const CONSUMER_NAME = `consumer-${process.pid}`; // Unique consumer name

const setupRedisStreamConsumer = async () => {
  try {
    // Try to create consumer group, ignore if it already exists
    await redis.xgroup('CREATE', STREAM_KEY, CONSUMER_GROUP, '$', 'MKSTREAM').catch((err: any) => {
      if (err.message.includes('BUSYGROUP')) {
        console.log(`Consumer group "${CONSUMER_GROUP}" already exists.`);
      } else {
        throw err;
      }
    });

    console.log(`Redis Stream Consumer "${CONSUMER_NAME}" for group "${CONSUMER_GROUP}" starting...`);

    while (true) {
      try {
        // Read new messages from the stream for this consumer group
        const messages = await redis.xreadgroup(
          'GROUP', CONSUMER_GROUP, CONSUMER_NAME,
          'BLOCK', 0, // Block indefinitely until messages arrive
          'COUNT', 1, // Read one message at a time
          'STREAMS', STREAM_KEY, '>' // Read new messages, '>' means from the next ID after the last one processed
        );

        if (messages && messages.length > 0) {
          for (const streamEntry of messages) {
            const streamName = streamEntry[0];
            const messageEntries = streamEntry[1];

            for (const message of messageEntries) {
              const messageId = message[0];
              const messageData = message[1];
              const eventPayload = JSON.parse(messageData[1]); // Assuming 'data' field is always the second element

              console.log(`Received event from ${streamName} (ID: ${messageId}):`, eventPayload);

              // Process the event
              await processIncomingEvent(eventPayload);

              // Acknowledge the message
              await redis.xack(STREAM_KEY, CONSUMER_GROUP, messageId);
              console.log(`Acknowledged message ID: ${messageId}`);
            }
          }
        }
      } catch (readError) {
        console.error('Error reading from Redis stream:', readError);
        // Implement backoff or retry logic here
        await new Promise(resolve => setTimeout(resolve, 5000)); // Wait 5 seconds before retrying
      }
    }
  } catch (initError) {
    console.error('Error initializing Redis Stream consumer:', initError);
  }
};

export default setupRedisStreamConsumer;
EOF
echo "lib/redis-stream-consumer.ts created."

# services/event-processor.ts
echo "Creating services/event-processor.ts..."
cat <<'EOF' > services/event-processor.ts
import { publishToRedisStream } from '@/lib/redis';

// This function simulates processing an incoming event and writing to other queues.
export const processIncomingEvent = async (event: any) => {
  console.log('Processing incoming event:', event);

  // Example: Based on the event type, publish to different queues
  if (event.type === 'PERSON_CREATED' || event.operationType === 'insert') {
    await publishToRedisStream('microservice-x', 'new:person:event', {
      ...event,
      processedBy: 'nextjs-app',
      timestamp: new Date().toISOString(),
    });
    console.log('Published to microservice-x:new:person:event');
  } else if (event.type === 'COMPANY_UPDATED' || event.operationType === 'update') {
    await publishToRedisStream('microservice-y', 'company:update:event', {
      ...event,
      processedBy: 'nextjs-app',
      timestamp: new Date().toISOString(),
    });
    console.log('Published to microservice-y:company:update:event');
  } else {
    console.log('Unhandled event type, publishing to general events queue.');
    await publishToRedisStream('general-events', 'unhandled:event', {
      ...event,
      processedBy: 'nextjs-app',
      timestamp: new Date().toISOString(),
    });
  }

  // In a real application, this would involve more complex business logic:
  // - Validating the event data
  // - Performing database operations (if needed, but usually microservices handle their own persistence)
  // - Calling other internal services
  // - Sending notifications
};
EOF
echo "services/event-processor.ts created."

# types/index.d.ts
echo "Creating types/index.d.ts..."
cat <<'EOF' > types/index.d.ts
import mongoose from 'mongoose';

declare global {
  var mongoose: {
    conn: typeof mongoose | null;
    promise: Promise<typeof mongoose> | null;
  };
}
EOF
echo "types/index.d.ts created."

# README.md (Basic placeholder)
echo "Creating README.md..."
cat <<'EOF' > README.md
# Fullstack Next.js Application

This project is a full-stack Next.js application demonstrating:

* CRUD operations for `People` and `Companies` collections using MongoDB.
* Real-time change data capture from MongoDB using Change Streams.
* Event publishing to Redis Streams (`redis-integration-db:la:people:changes`, `redis-integration-db:la:companies:changes`).
* Event consumption from a Redis Stream (`la:people:sync:request`) using Redis Consumer Groups.
* Containerization using Docker Compose.

**To get started, follow the steps outlined in the bash script's output or refer to the comprehensive guide.**
EOF
echo "README.md created."

echo "All directories and files have been created successfully!"
echo ""
echo "--- Next Steps ---"
echo "1. Navigate into the created project directory (if you ran the script outside it):"
echo "   cd my-fullstack-app (or whatever directory you ran the script in)"
echo "2. Install Node.js dependencies:"
echo "   yarn install"
echo "   (or npm install)"
echo "3. Run the Docker Compose setup:"
echo "   docker compose up --build"
echo "4. Access the application in your browser at: http://localhost:3000"
echo "5. You can also manually create tailwind.config.ts and postcss.config.js for tailwind to work:"
echo "   npx tailwindcss init -p"

