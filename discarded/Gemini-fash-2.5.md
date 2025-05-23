## Prompt:  
As un expert in NextJS Framework, typescript and mondodb, write a fullstack app in NExtJS the follows the requrements below:

1. has options to manitain entirely (CRUD operations) for 2 colletions (People and Companies) into a mongodb no-sql database (latest stable version). THe UI should be modern ofering a good user experience.

2. It shoud capture any insert update,delete events in mongodb and send the essential data of each database transaction to a Redis stream addressed by service "redis-integration-db" and queue "la:people:changes".

3. it also should bubscribe to a cosumer group assigned to the queue la:people:sync:request, reads all event in this queue and proceess each one writing events in other queues cosumed by other microservices.

4. this app should be containeraized using docker-compose.yml file.

5. uses always as possible the latest stable version for each part (fontend resources, backend ressources

6. describe all sttes to be executed to have this app up and running.  

## Answer:  
This document outlines the architecture, implementation details, and deployment steps for a full-stack Next.js application. This application will provide CRUD operations for "People" and "Companies" collections in MongoDB, capture database changes, push them to a Redis Stream, and consume events from another Redis Stream for processing.

We will prioritize using the latest stable versions of all technologies.

Technologies Used (Latest Stable Versions as of May 2025):

Next.js: 15.3 (with App Router)
React: 18.x
TypeScript: 5.x
MongoDB: 8.0
Mongoose: 8.x (for MongoDB ORM)
Redis: 8.0.x
ioredis: 5.x (Redis client for Node.js)
Docker & Docker Compose: 2.x

1. Project structure: 
.
├── app/
│   ├── api/
│   │   ├── people/
│   │   │   ├── route.ts (GET, POST)
│   │   │   └── [id]/
│   │   │       └── route.ts (GET, PUT, DELETE)
│   │   ├── companies/
│   │   │   ├── route.ts (GET, POST)
│   │   │   └── [id]/
│   │   │       └── route.ts (GET, PUT, DELETE)
│   │   └── webhooks/
│   │       └── redis-consumer.ts (Handles incoming Redis stream events)
│   ├── components/
│   │   ├── PersonForm.tsx
│   │   ├── CompanyForm.tsx
│   │   ├── DataTable.tsx
│   │   └── Modal.tsx
│   ├── people/
│   │   └── page.tsx
│   ├── companies/
│   │   └── page.tsx
│   ├── layout.tsx
│   └── page.tsx
├── lib/
│   ├── mongodb.ts (MongoDB connection)
│   ├── redis.ts (Redis client setup)
│   ├── models/
│   │   ├── Person.ts (Mongoose Schema)
│   │   └── Company.ts (Mongoose Schema)
│   ├── db-change-stream.ts (MongoDB Change Stream logic)
│   └── redis-stream-consumer.ts (Redis Stream consumer logic)
├── services/
│   └── event-processor.ts (Logic for processing incoming Redis events)
├── public/
├── types/
│   ├── index.d.ts (TypeScript interfaces)
├── .env.local
├── docker-compose.yml
├── Dockerfile
├── package.json
├── tsconfig.json
└── README.md  

2. Core implementation Details:  

2.1 MOngoDB and Mongoose MOdels:
lib/mongodb.ts
```typescript
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
```  
lib/models/Person.ts
```typescript
import mongoose, { Schema, Document } from 'mongoose';

export interface IPerson extends Document {
  name: string;
  email: string;
  age: number;
  companyId?: mongoose.Types.ObjectId; // Optional link to Company
}

const PersonSchema: Schema = new Schema({
  name: { type: String, required: true },
  email: { type: String, required: true, unique: true },
  age: { type: Number, required: true },
  companyId: { type: Schema.Types.ObjectId, ref: 'Company' },
});

const Person = mongoose.models.Person || mongoose.model<IPerson>('Person', PersonSchema);

export default Person; 
```  
lib/models/Company.ts:  
```typescript
import mongoose, { Schema, Document } from 'mongoose';

export interface ICompany extends Document {
  name: string;
  address: string;
  industry: string;
}

const CompanySchema: Schema = new Schema({
  name: { type: String, required: true, unique: true },
  address: { type: String, required: true },
  industry: { type: String, required: true },
});

const Company = mongoose.models.Company || mongoose.model<ICompany>('Company', CompanySchema);

export default Company;  
```  
types/index.d.ts:
```typescript
import mongoose from 'mongoose';

declare global {
  var mongoose: {
    conn: typeof mongoose | null;
    promise: Promise<typeof mongoose> | null;
  };
}
```  
2.2 Next.js API Routes (CRUD Operations):
app/api/people/route.ts (GET all, Post new):  
```typescript
import { NextResponse } from 'next/server';
import dbConnect from '@/lib/mongodb';
import Person from '@/lib/models/Person';

export async function GET() {
  await dbConnect();
  try {
    const people = await Person.find({});
    return NextResponse.json(people, { status: 200 });
  } catch (error) {
    return NextResponse.json({ message: 'Error fetching people', error }, { status: 500 });
  }
}

export async function POST(req: Request) {
  await dbConnect();
  try {
    const body = await req.json();
    const newPerson = await Person.create(body);
    return NextResponse.json(newPerson, { status: 201 });
  } catch (error) {
    return NextResponse.json({ message: 'Error creating person', error }, { status: 500 });
  }
}
```  
app/api/people/[id]/route.ts (GET by ID, PUT, DELETE):
```typescript
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
    return NextResponse.json({ message: 'Error fetching person', error }, { status: 500 });
  }
}

export async function PUT(req: Request, { params }: { params: { id: string } }) {
  await dbConnect();
  const { id } = params;
  try {
    const body = await req.json();
    const updatedPerson = await Person.findByIdAndUpdate(id, body, { new: true });
    if (!updatedPerson) {
      return NextResponse.json({ message: 'Person not found' }, { status: 404 });
    }
    return NextResponse.json(updatedPerson, { status: 200 });
  } catch (error) {
    return NextResponse.json({ message: 'Error updating person', error }, { status: 500 });
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
    return NextResponse.json({ message: 'Error deleting person', error }, { status: 500 });
  }
}
```  
(Similar route.ts files would be created for app/api/companies) 

2.3 Modern UI (React Components):  
app/components/DataTable.tsx:
```typescript  
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
```  
(Forms and Modals would be similar, using Tailwind CSS for styling as an example)  

2.4 MOngoDB Change Streams:
lib/db-change-stream.ts
```typescript
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

```
This document outlines the architecture, implementation details, and deployment steps for a full-stack Next.js application. This application will provide CRUD operations for "People" and "Companies" collections in MongoDB, capture database changes, push them to a Redis Stream, and consume events from another Redis Stream for processing.

We will prioritize using the latest stable versions of all technologies.

Technologies Used (Latest Stable Versions as of May 2025):

Next.js: 15.3 (with App Router)
React: 18.x
TypeScript: 5.x
MongoDB: 8.0
Mongoose: 8.x (for MongoDB ORM)
Redis: 8.0.x
ioredis: 5.x (Redis client for Node.js)
Docker & Docker Compose: 2.x
1. Project Structure
.
├── app/
│   ├── api/
│   │   ├── people/
│   │   │   ├── route.ts (GET, POST)
│   │   │   └── [id]/
│   │   │       └── route.ts (GET, PUT, DELETE)
│   │   ├── companies/
│   │   │   ├── route.ts (GET, POST)
│   │   │   └── [id]/
│   │   │       └── route.ts (GET, PUT, DELETE)
│   │   └── webhooks/
│   │       └── redis-consumer.ts (Handles incoming Redis stream events)
│   ├── components/
│   │   ├── PersonForm.tsx
│   │   ├── CompanyForm.tsx
│   │   ├── DataTable.tsx
│   │   └── Modal.tsx
│   ├── people/
│   │   └── page.tsx
│   ├── companies/
│   │   └── page.tsx
│   ├── layout.tsx
│   └── page.tsx
├── lib/
│   ├── mongodb.ts (MongoDB connection)
│   ├── redis.ts (Redis client setup)
│   ├── models/
│   │   ├── Person.ts (Mongoose Schema)
│   │   └── Company.ts (Mongoose Schema)
│   ├── db-change-stream.ts (MongoDB Change Stream logic)
│   └── redis-stream-consumer.ts (Redis Stream consumer logic)
├── services/
│   └── event-processor.ts (Logic for processing incoming Redis events)
├── public/
├── types/
│   ├── index.d.ts (TypeScript interfaces)
├── .env.local
├── docker-compose.yml
├── Dockerfile
├── package.json
├── tsconfig.json
└── README.md
2. Core Implementation Details
2.1. MongoDB Database and Mongoose Models
We'll define Mongoose schemas for Person and Company.

lib/mongodb.ts

TypeScript

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
lib/models/Person.ts

TypeScript

import mongoose, { Schema, Document } from 'mongoose';

export interface IPerson extends Document {
  name: string;
  email: string;
  age: number;
  companyId?: mongoose.Types.ObjectId; // Optional link to Company
}

const PersonSchema: Schema = new Schema({
  name: { type: String, required: true },
  email: { type: String, required: true, unique: true },
  age: { type: Number, required: true },
  companyId: { type: Schema.Types.ObjectId, ref: 'Company' },
});

const Person = mongoose.models.Person || mongoose.model<IPerson>('Person', PersonSchema);

export default Person;
lib/models/Company.ts

TypeScript

import mongoose, { Schema, Document } from 'mongoose';

export interface ICompany extends Document {
  name: string;
  address: string;
  industry: string;
}

const CompanySchema: Schema = new Schema({
  name: { type: String, required: true, unique: true },
  address: { type: String, required: true },
  industry: { type: String, required: true },
});

const Company = mongoose.models.Company || mongoose.model<ICompany>('Company', CompanySchema);

export default Company;
types/index.d.ts

TypeScript

import mongoose from 'mongoose';

declare global {
  var mongoose: {
    conn: typeof mongoose | null;
    promise: Promise<typeof mongoose> | null;
  };
}
2.2. Next.js API Routes (CRUD Operations)
Next.js API routes will serve as our backend. We'll use the App Router's route.ts files.

app/api/people/route.ts (GET all, POST new)

TypeScript

import { NextResponse } from 'next/server';
import dbConnect from '@/lib/mongodb';
import Person from '@/lib/models/Person';

export async function GET() {
  await dbConnect();
  try {
    const people = await Person.find({});
    return NextResponse.json(people, { status: 200 });
  } catch (error) {
    return NextResponse.json({ message: 'Error fetching people', error }, { status: 500 });
  }
}

export async function POST(req: Request) {
  await dbConnect();
  try {
    const body = await req.json();
    const newPerson = await Person.create(body);
    return NextResponse.json(newPerson, { status: 201 });
  } catch (error) {
    return NextResponse.json({ message: 'Error creating person', error }, { status: 500 });
  }
}
app/api/people/[id]/route.ts (GET by ID, PUT, DELETE)

TypeScript

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
    return NextResponse.json({ message: 'Error fetching person', error }, { status: 500 });
  }
}

export async function PUT(req: Request, { params }: { params: { id: string } }) {
  await dbConnect();
  const { id } = params;
  try {
    const body = await req.json();
    const updatedPerson = await Person.findByIdAndUpdate(id, body, { new: true });
    if (!updatedPerson) {
      return NextResponse.json({ message: 'Person not found' }, { status: 404 });
    }
    return NextResponse.json(updatedPerson, { status: 200 });
  } catch (error) {
    return NextResponse.json({ message: 'Error updating person', error }, { status: 500 });
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
    return NextResponse.json({ message: 'Error deleting person', error }, { status: 500 });
  }
}
(Similar route.ts files would be created for app/api/companies)

2.3. Modern UI (React Components)
We'll use simple React components for the UI, focusing on functionality and a good user experience. For a more robust UI, you might integrate a component library like Material UI, Ant Design, or Chakra UI.

app/components/DataTable.tsx

TypeScript

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
(Forms and Modals would be similar, using Tailwind CSS for styling as an example)

2.4. MongoDB Change Streams
MongoDB Change Streams will be used to capture all insert, update, and delete events. This requires a replica set or sharded cluster. For local development, docker-compose will set up a single-node replica set.

lib/db-change-stream.ts

TypeScript

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
Note: For setupChangeStreams to run on server start, you'd typically call it once the MongoDB connection is established. In a Next.js environment, this might be tricky with serverless functions. A robust solution often involves a dedicated long-running process (e.g., a separate Docker container) for the change stream listener, or ensuring the listener is initialized when the Next.js API route first connects to MongoDB if it's running in a persistent server environment (like a custom server). For this example, we'll assume it's initialized on server startup within the Next.js app's "server" side.  

2.5 Redis Integration: 

We'll use ioredis for Redis interactions.

lib/redis.ts
```typescript  
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

```  
2.6. Redis-strem-consumer.ts
```typescript
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
```  
services/event-processor.ts
```typescript
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
```  
Integrating the Redis Consumer into Next.js:

Since Next.js API routes are serverless by default, a long-running Redis consumer needs careful consideration.

* Option 1 (Recommended for dedicated listener): Separate Process/Container: The lib/redis-stream-consumer.ts could be run as a separate Node.js script or even a separate Docker container in your docker-compose.yml. This ensures it's always running independently of Next.js's API route lifecycle.
* Option 2 (Less ideal for high-throughput, but possible): Next.js API Route for "Warm-up" or Webhook: You could potentially trigger the consumer logic from an API route (e.g., /api/webhooks/redis-consumer.ts). This is less robust for continuous processing but might work for specific use cases or if you're deploying to a platform that keeps API routes "warm." For this example, we'll show a basic API route that could initiate it, but note the caveats.  

app/api/webhooks/redis-consumer.ts (ilustrative.prefer Option 1)
```typescript
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
```  

2.7. Frontend Pages:
app/people/page.tsx
```typescript
'use client';

import React, { useState, useEffect } from 'react';
import { DataTable } from '@/app/components/DataTable';
import { Modal } from '@/app/components/Modal';
import PersonForm from '@/app/components/PersonForm';

interface Person {
  _id: string;
  name: string;
  email: string;
  age: number;
  companyId?: string; // Assuming it's just the ID for display
}

export default function PeoplePage() {
  const [people, setPeople] = useState<Person[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [currentPerson, setCurrentPerson] = useState<Person | null>(null);

  const fetchPeople = async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await fetch('/api/people');
      if (!res.ok) {
        throw new Error(`HTTP error! status: ${res.status}`);
      }
      const data: Person[] = await res.json();
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

  const handleAddEdit = async (personData: Partial<Person>) => {
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
      alert(`Error saving person: ${e.message}`);
    }
  };

  const handleDelete = async (person: Person) => {
    if (!confirm(`Are you sure you want to delete ${person.name}?`)) return;
    try {
      const res = await fetch(`/api/people/${person._id}`, { method: 'DELETE' });
      if (!res.ok) {
        const errorData = await res.json();
        throw new Error(errorData.message || 'Failed to delete person');
      }
      await fetchPeople();
    } catch (e: any) {
      alert(`Error deleting person: ${e.message}`);
    }
  };

  const openAddModal = () => {
    setCurrentPerson(null);
    setIsModalOpen(true);
  };

  const openEditModal = (person: Person) => {
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

      <DataTable<Person>
        data={people}
        columns={[
          { header: 'Name', accessor: 'name' },
          { header: 'Email', accessor: 'email' },
          { header: 'Age', accessor: 'age' },
          { header: 'Company ID', accessor: (p) => p.companyId?.toString() || 'N/A' },
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
```  
(Similar app/companies/page.tsx)  

---  

3. Containerization with Docker Compose:  
docker-compose.yml:  
```yaml  
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
```  
Dockerfile: (for Next.js app)
```dockerfile
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
```  
mongo-init.js: (for MOngoDB replica set initiation)
```javascript
var config = {
    _id: "rs0",
    members: [
        { _id: 0, host: "localhost:27017" } // Using localhost for internal Docker network
    ]
};
rs.initiate(config);
rs.conf();
```  
Important Note for Dockerfile CMD: The CMD in the Dockerfile attempts to run dbConnect and setupChangeStreams as background processes alongside yarn start. This is a simplification. For a robust production environment, consider:

* Dedicated Worker Container: A separate nextjs-worker service in docker-compose.yml that only runs lib/db-change-stream.ts and lib/redis-stream-consumer.ts. This decouples the event processing from the web server.
* Next.js Custom Server: If you need to keep long-running processes within the Next.js application, you'd use a custom server.js (or server.ts) file, which allows you to start the change stream and Redis consumer when the server initializes, rather than relying on serverless function invocations.  

4. Environment Variables:

.env.local (at the root of your project):
```env
MONGODB_URI=mongodb://admin:password@localhost:27017/mydatabase?authSource=admin&replicaSet=rs0
REDIS_URL=redis://localhost:6379

MONGO_INITDB_ROOT_USERNAME=admin
MONGO_INITDB_ROOT_PASSWORD=password
```  
5. Steps to get this app up and running:  
5.1. Prerequisites:
* Docker Desktop (or Docker Engine) installed on your machine.
Install Docker Desktop (includes Docker Engine and Docker Compose) for your operating system.

5.2. Initialize Next.js project:  
* Create a new Next.js project with TypeScript:
```bash
npx create-next-app@latest my-fullstack-app --typescript --eslint --tailwind --app
cd my-fullstack-app
```  
* Install Additional Dependencies:  
```bash
yarn add mongoose ioredis
yarn add -D @types/mongoose @types/ioredis
```  
5.3. Create Project Files Directories:
* ollow the "Project Structure" section to create all the files and directories (app/, lib/, services/, types/, .env.local, docker-compose.yml, Dockerfile, mongo-init.js).  
* Copy and paste the code provided in sections 2 and 3 into the respective files.

5.4. Confgure .env.local:
* Update the .env.local file with your MongoDB and Redis connection details.
Update the .env.local file with your desired MongoDB credentials and Redis connection string. Make sure MONGO_INITDB_ROOT_USERNAME and MONGO_INITDB_ROOT_PASSWORD in .env.local match what's set in docker-compose.yml.  
* rUN THE FOLLOWING COMMANDS TO BUILD THE IMAGES AND START THE SERVERS:
```bash
docker compose up --build
```
This command will:
* Build the nextjs-app image using the Dockerfile.
* PUll mongo:8.0 and redis:8.0.0-alpine images from Docker Hub.
* Start the MongoDB container, initialize the repica set, and wait for it to be healthy.
* Start the Redis container and wait for it to be healthy.
* Start the nextjs-app container, which will build the Next.js app using the built image.

6. Verify Services:
* Once all services are up, you should see logs from each container in your terminal.
* Next.js App: The Next.js application should be accessible at http://localhost:3000.
* MongoDB: You can connect to MongoDB from your host machine using mongosh (if * installed) or a GUI tool like MongoDB Compass at mongodb://localhost:27017.
* Redis: You can connect to Redis using redis-cli (if installed) at redis-cli -h localhost -p 6379.

7. Test Functionality:
*Navigate to http://localhost:3000/people and http://localhost:3000/companies in your browser.
* Use the UI to perform CRUD operations (Add, Edit, Delete) for People and Companies.
* Observe Change Streams: Check the terminal where docker compose up is running. You should see console logs from lib/db-change-stream.ts indicating "Change detected in people" or "Change detected in companies" whenever you perform a CRUD operation.
* Observe Redis Stream Publishing: Following the change detection logs, you should also see "Published to Redis Stream..." messages.
* Observe Redis Stream Consumption: You should see logs from lib/redis-stream-consumer.ts like "Received event from la:people:sync:request..." and "Processing incoming event..." as it consumes and processes messages.

8. Troubleshooting:
* If containers fail to start, check the docker compose logs for specific error messages.
* Ensure your .env.local file is correctly configured and located at the project root.
* If MongoDB change streams don't work, verify that the replica set was initiated correctly (check mongo-init.js and MongoDB container logs). You might need to docker compose down -v and docker compose up --build to ensure a clean start if there were issues with volume persistence.
* For Redis connectivity, check firewall rules if you have any.

This comprehensive setup provides a robust full-stack Next.js application with MongoDB CRUD, real-time database change capturing, and event-driven architecture using Redis Streams, all containerized for easy deployment.   

---  

## Prompt:  
Rewrite the latest answer, now considering the the 2 collections (People and Companies) has the respective JSON schemas below:
1. People: https://github.com/lar-alvorecer/la-people-app/blob/main/json_schemas/people_schema.json

2. Companies: https://github.com/lar-alvorecer/la-people-app/blob/main/json_schemas/companies_schema.json  


## Answer:  
This document outlines the architecture, implementation details, and deployment steps for a full-stack Next.js application, now incorporating the provided JSON schemas for the "People" and "Companies" collections. This application will provide CRUD operations for these collections in MongoDB, capture database changes, push them to a Redis Stream, and consume events from another Redis Stream for processing.

We will prioritize using the latest stable versions of all technologies.

Technologies Used (Latest Stable Versions as of May 2025):

Next.js: 15.3 (with App Router)
React: 18.x
TypeScript: 5.x
MongoDB: 8.0
Mongoose: 8.x (for MongoDB ORM)
Redis: 8.0.x
ioredis: 5.x (Redis client for Node.js)
Docker & Docker Compose: 2.x
1. Project Structure
.
├── app/
│   ├── api/
│   │   ├── people/
│   │   │   ├── route.ts (GET, POST)
│   │   │   └── [id]/
│   │   │       └── route.ts (GET, PUT, DELETE)
│   │   ├── companies/
│   │   │   ├── route.ts (GET, POST)
│   │   │   └── [id]/
│   │   │       └── route.ts (GET, PUT, DELETE)
│   │   └── webhooks/
│   │       └── redis-consumer.ts (Handles incoming Redis stream events)
│   ├── components/
│   │   ├── PersonForm.tsx
│   │   ├── CompanyForm.tsx
│   │   ├── DataTable.tsx
│   │   └── Modal.tsx
│   ├── people/
│   │   └── page.tsx
│   ├── companies/
│   │   └── page.tsx
│   ├── layout.tsx
│   └── page.tsx
├── lib/
│   ├── mongodb.ts (MongoDB connection)
│   ├── redis.ts (Redis client setup)
│   ├── models/
│   │   ├── Person.ts (Mongoose Schema)
│   │   └── Company.ts (Mongoose Schema)
│   ├── db-change-stream.ts (MongoDB Change Stream logic)
│   └── redis-stream-consumer.ts (Redis Stream consumer logic)
├── services/
│   └── event-processor.ts (Logic for processing incoming Redis events)
├── public/
├── types/
│   ├── index.d.ts (TypeScript interfaces)
├── .env.local
├── docker-compose.yml
├── Dockerfile
├── package.json
├── tsconfig.json
└── README.md

2. corre IMplementation Details:

2.1. MOndoDB

This document outlines the architecture, implementation details, and deployment steps for a full-stack Next.js application, now incorporating the provided JSON schemas for the "People" and "Companies" collections. This application will provide CRUD operations for these collections in MongoDB, capture database changes, push them to a Redis Stream, and consume events from another Redis Stream for processing.

We will prioritize using the latest stable versions of all technologies.

Technologies Used (Latest Stable Versions as of May 2025):

Next.js: 15.3 (with App Router)
React: 18.x
TypeScript: 5.x
MongoDB: 8.0
Mongoose: 8.x (for MongoDB ORM)
Redis: 8.0.x
ioredis: 5.x (Redis client for Node.js)
Docker & Docker Compose: 2.x
1. Project Structure
The project structure remains largely the same, with updates to the Mongoose models and the addition of new form components.
.
├── app/
│   ├── api/
│   │   ├── people/
│   │   │   ├── route.ts (GET, POST)
│   │   │   └── [id]/
│   │   │       └── route.ts (GET, PUT, DELETE)
│   │   ├── companies/
│   │   │   ├── route.ts (GET, POST)
│   │   │   └── [id]/
│   │   │       └── route.ts (GET, PUT, DELETE)
│   │   └── webhooks/
│   │       └── redis-consumer.ts (Handles incoming Redis stream events)
│   ├── components/
│   │   ├── PersonForm.tsx
│   │   ├── CompanyForm.tsx
│   │   ├── DataTable.tsx
│   │   └── Modal.tsx
│   ├── people/
│   │   └── page.tsx
│   ├── companies/
│   │   └── page.tsx
│   ├── layout.tsx
│   └── page.tsx
├── lib/
│   ├── mongodb.ts (MongoDB connection)
│   ├── redis.ts (Redis client setup)
│   ├── models/
│   │   ├── Person.ts (Mongoose Schema)
│   │   └── Company.ts (Mongoose Schema)
│   ├── db-change-stream.ts (MongoDB Change Stream logic)
│   └── redis-stream-consumer.ts (Redis Stream consumer logic)
├── services/
│   └── event-processor.ts (Logic for processing incoming Redis events)
├── public/
├── types/
│   ├── index.d.ts (TypeScript interfaces)
├── .env.local
├── docker-compose.yml
├── Dockerfile
├── package.json
├── tsconfig.json
└── README.md
2. Core Implementation Details
2.1. MongoDB Database and Mongoose Models (Updated with JSON Schemas)
We'll update the Mongoose schemas and TypeScript interfaces to reflect the provided JSON schemas.

lib/mongodb.ts (No change from previous version)
```typescript
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
```  
lib/models/Person.ts (Updated with JSON Schema)
```typescript  
import mongoose, { Schema, Document } from 'mongoose';

export interface IPerson extends Document {
  firstName: string;
  lastName: string;
  email: string;
  birthDate: string; // YYYY-MM-DD
  gender: 'Male' | 'Female' | 'Other';
  companyId?: mongoose.Types.ObjectId; // Optional link to Company
  createdAt: Date;
  updatedAt: Date;
}

const PersonSchema: Schema = new Schema({
  firstName: { type: String, required: true, minlength: 1 },
  lastName: { type: String, required: true, minlength: 1 },
  email: { type: String, required: true, unique: true, match: /^\S+@\S+\.\S+$/ },
  birthDate: { type: String, required: true, match: /^\d{4}-\d{2}-\d{2}$/ }, // YYYY-MM-DD format
  gender: { type: String, required: true, enum: ['Male', 'Female', 'Other'] },
  companyId: { type: Schema.Types.ObjectId, ref: 'Company', default: null }, // Nullable
}, { timestamps: true }); // Mongoose handles createdAt and updatedAt

const Person = mongoose.models.Person || mongoose.model<IPerson>('Person', PersonSchema);

export default Person;  
```  
lib/models/Company.ts (Updated with JSON Schema)
```typescript
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
```  
2.2. Next.js API Routes (CRUD Operations)
The API routes will largely remain the same in structure, but the body content they receive and send will now conform to the new schemas. Mongoose's validation will handle the schema constraints.

app/api/people/route.ts (GET all, POST new) (Updated to reflect new schema fields)
```typescript
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
```  
app/api/people/[id]/route.ts (GET by ID, PUT, DELETE) (Updated to reflect new schema fields)
```typescript
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
```  
This document outlines the architecture, implementation details, and deployment steps for a full-stack Next.js application, now incorporating the provided JSON schemas for the "People" and "Companies" collections. This application will provide CRUD operations for these collections in MongoDB, capture database changes, push them to a Redis Stream, and consume events from another Redis Stream for processing.

We will prioritize using the latest stable versions of all technologies.

Technologies Used (Latest Stable Versions as of May 2025):

Next.js: 15.3 (with App Router)
React: 18.x
TypeScript: 5.x
MongoDB: 8.0
Mongoose: 8.x (for MongoDB ORM)
Redis: 8.0.x
ioredis: 5.x (Redis client for Node.js)
Docker & Docker Compose: 2.x
1. Project Structure
The project structure remains largely the same, with updates to the Mongoose models and the addition of new form components.

.
├── app/
│   ├── api/
│   │   ├── people/
│   │   │   ├── route.ts (GET, POST)
│   │   │   └── [id]/
│   │   │       └── route.ts (GET, PUT, DELETE)
│   │   ├── companies/
│   │   │   ├── route.ts (GET, POST)
│   │   │   └── [id]/
│   │   │       └── route.ts (GET, PUT, DELETE)
│   │   └── webhooks/
│   │       └── redis-consumer.ts (Handles incoming Redis stream events)
│   ├── components/
│   │   ├── PersonForm.tsx
│   │   ├── CompanyForm.tsx
│   │   ├── DataTable.tsx
│   │   └── Modal.tsx
│   ├── people/
│   │   └── page.tsx
│   ├── companies/
│   │   └── page.tsx
│   ├── layout.tsx
│   └── page.tsx
├── lib/
│   ├── mongodb.ts (MongoDB connection)
│   ├── redis.ts (Redis client setup)
│   ├── models/
│   │   ├── Person.ts (Mongoose Schema)
│   │   └── Company.ts (Mongoose Schema)
│   ├── db-change-stream.ts (MongoDB Change Stream logic)
│   └── redis-stream-consumer.ts (Redis Stream consumer logic)
├── services/
│   └── event-processor.ts (Logic for processing incoming Redis events)
├── public/
├── types/
│   ├── index.d.ts (TypeScript interfaces)
├── .env.local
├── docker-compose.yml
├── Dockerfile
├── package.json
├── tsconfig.json
└── README.md
2. Core Implementation Details
2.1. MongoDB Database and Mongoose Models (Updated with JSON Schemas)
We'll update the Mongoose schemas and TypeScript interfaces to reflect the provided JSON schemas.

lib/mongodb.ts (No change from previous version)

TypeScript

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
lib/models/Person.ts (Updated with People Schema)

TypeScript

import mongoose, { Schema, Document } from 'mongoose';

export interface IPerson extends Document {
  firstName: string;
  lastName: string;
  email: string;
  birthDate: string; // YYYY-MM-DD
  gender: 'Male' | 'Female' | 'Other';
  companyId?: mongoose.Types.ObjectId; // Optional link to Company
  createdAt: Date;
  updatedAt: Date;
}

const PersonSchema: Schema = new Schema({
  firstName: { type: String, required: true, minlength: 1 },
  lastName: { type: String, required: true, minlength: 1 },
  email: { type: String, required: true, unique: true, match: /^\S+@\S+\.\S+$/ },
  birthDate: { type: String, required: true, match: /^\d{4}-\d{2}-\d{2}$/ }, // YYYY-MM-DD format
  gender: { type: String, required: true, enum: ['Male', 'Female', 'Other'] },
  companyId: { type: Schema.Types.ObjectId, ref: 'Company', default: null }, // Nullable
}, { timestamps: true }); // Mongoose handles createdAt and updatedAt

const Person = mongoose.models.Person || mongoose.model<IPerson>('Person', PersonSchema);

export default Person;
lib/models/Company.ts (Updated with Companies Schema)

TypeScript

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
types/index.d.ts (No change from previous version)

TypeScript

import mongoose from 'mongoose';

declare global {
  var mongoose: {
    conn: typeof mongoose | null;
    promise: Promise<typeof mongoose> | null;
  };
}
2.2. Next.js API Routes (CRUD Operations)
The API routes will largely remain the same in structure, but the body content they receive and send will now conform to the new schemas. Mongoose's validation will handle the schema constraints.

app/api/people/route.ts (GET all, POST new) (Updated to reflect new schema fields)

TypeScript

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
app/api/people/[id]/route.ts (GET by ID, PUT, DELETE) (Updated to reflect new schema fields)

TypeScript

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
(Similar route.ts files would be created for app/api/companies)  

2.3 MOder UI (React Components)
The UI components will need significant updates to reflect the new schema fields and provide input forms for them.  
This document outlines the architecture, implementation details, and deployment steps for a full-stack Next.js application, now incorporating the provided JSON schemas for the "People" and "Companies" collections. This application will provide CRUD operations for these collections in MongoDB, capture database changes, push them to a Redis Stream, and consume events from another Redis Stream for processing.

We will prioritize using the latest stable versions of all technologies.

Technologies Used (Latest Stable Versions as of May 2025):

Next.js: 15.3 (with App Router)
React: 18.x
TypeScript: 5.x
MongoDB: 8.0
Mongoose: 8.x (for MongoDB ORM)
Redis: 8.0.x
ioredis: 5.x (Redis client for Node.js)
Docker & Docker Compose: 2.x
1. Project Structure
The project structure remains largely the same, with updates to the Mongoose models and the addition of new form components.

.
├── app/
│   ├── api/
│   │   ├── people/
│   │   │   ├── route.ts (GET, POST)
│   │   │   └── [id]/
│   │   │       └── route.ts (GET, PUT, DELETE)
│   │   ├── companies/
│   │   │   ├── route.ts (GET, POST)
│   │   │   └── [id]/
│   │   │       └── route.ts (GET, PUT, DELETE)
│   │   └── webhooks/
│   │       └── redis-consumer.ts (Handles incoming Redis stream events)
│   ├── components/
│   │   ├── PersonForm.tsx
│   │   ├── CompanyForm.tsx
│   │   ├── DataTable.tsx
│   │   └── Modal.tsx
│   ├── people/
│   │   └── page.tsx
│   ├── companies/
│   │   └── page.tsx
│   ├── layout.tsx
│   └── page.tsx
├── lib/
│   ├── mongodb.ts (MongoDB connection)
│   ├── redis.ts (Redis client setup)
│   ├── models/
│   │   ├── Person.ts (Mongoose Schema)
│   │   └── Company.ts (Mongoose Schema)
│   ├── db-change-stream.ts (MongoDB Change Stream logic)
│   └── redis-stream-consumer.ts (Redis Stream consumer logic)
├── services/
│   └── event-processor.ts (Logic for processing incoming Redis events)
├── public/
├── types/
│   ├── index.d.ts (TypeScript interfaces)
├── .env.local
├── docker-compose.yml
├── Dockerfile
├── package.json
├── tsconfig.json
└── README.md
2. Core Implementation Details
2.1. MongoDB Database and Mongoose Models (Updated with JSON Schemas)
We'll update the Mongoose schemas and TypeScript interfaces to reflect the provided JSON schemas.

lib/mongodb.ts (No change from previous version)

TypeScript

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
lib/models/Person.ts (Updated with People Schema)

TypeScript

import mongoose, { Schema, Document } from 'mongoose';

export interface IPerson extends Document {
  firstName: string;
  lastName: string;
  email: string;
  birthDate: string; // YYYY-MM-DD
  gender: 'Male' | 'Female' | 'Other';
  companyId?: mongoose.Types.ObjectId; // Optional link to Company
  createdAt: Date;
  updatedAt: Date;
}

const PersonSchema: Schema = new Schema({
  firstName: { type: String, required: true, minlength: 1 },
  lastName: { type: String, required: true, minlength: 1 },
  email: { type: String, required: true, unique: true, match: /^\S+@\S+\.\S+$/ },
  birthDate: { type: String, required: true, match: /^\d{4}-\d{2}-\d{2}$/ }, // YYYY-MM-DD format
  gender: { type: String, required: true, enum: ['Male', 'Female', 'Other'] },
  companyId: { type: Schema.Types.ObjectId, ref: 'Company', default: null }, // Nullable
}, { timestamps: true }); // Mongoose handles createdAt and updatedAt

const Person = mongoose.models.Person || mongoose.model<IPerson>('Person', PersonSchema);

export default Person;
lib/models/Company.ts (Updated with Companies Schema)

TypeScript

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
types/index.d.ts (No change from previous version)

TypeScript

import mongoose from 'mongoose';

declare global {
  var mongoose: {
    conn: typeof mongoose | null;
    promise: Promise<typeof mongoose> | null;
  };
}
2.2. Next.js API Routes (CRUD Operations)
The API routes will largely remain the same in structure, but the body content they receive and send will now conform to the new schemas. Mongoose's validation will handle the schema constraints.

app/api/people/route.ts (GET all, POST new) (Updated to reflect new schema fields)

TypeScript

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
app/api/people/[id]/route.ts (GET by ID, PUT, DELETE) (Updated to reflect new schema fields)

TypeScript

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
(Similar route.ts files would be created for app/api/companies)

2.3. Modern UI (React Components)
The UI components will need significant updates to reflect the new schema fields and provide input forms for them.

app/components/DataTable.tsx (No change in DataTable component itself, but usage will change)
```typescript  
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
```  
app/components/Modal.tsx
```typescript
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
```  
app/components/PersonForm.tsx (New component for Person form - CRUD) 
```typescript
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
          type="date" // Use type="date" for better UX with date pickers
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

```  
app/components/CompanyForm.tsx (New component for Company CRUD)
```typescript
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
```  

app/people/page.tsx (Updated to use new IPerson and PersonForm)

```tsx
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
      messageBox.innerHTML = `
        <strong class="font-bold">Error!</strong>
        <span class="block sm:inline ml-2">${e.message}</span>
        <span class="absolute top-0 bottom-0 right-0 px-4 py-3 cursor-pointer" onclick="this.parentElement.remove()">
          <svg class="fill-current h-6 w-6 text-red-500" role="button" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20"><title>Close</title><path d="M14.348 14.849a1.2 1.2 0 0 1-1.697 0L10 11.103l-2.651 3.746a1.2 1.2 0 0 1-1.697-1.697l3.746-2.651-3.746-2.651a1.2 1.2 0 0 1 1.697-1.697L10 8.897l2.651-3.746a1.2 1.2 0 0 1 1.697 1.697L11.103 10l3.746 2.651a1.2 1.2 0 0 1 0 1.698z"/></svg>
        </span>
      `;
      document.body.appendChild(messageBox);
      setTimeout(() => messageBox.remove(), 5000); // Auto-remove after 5 seconds
    }
  };

  const handleDelete = async (person: IPerson) => {
    // Use a custom confirmation modal instead of confirm()
    const confirmDelete = window.confirm(`Are you sure you want to delete ${person.firstName} ${person.lastName}?`);
    if (!confirmDelete) return;

    try {
      const res = await fetch(`/api/people/${person._id}`, { method: 'DELETE' });
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
      messageBox.innerHTML = `
        <strong class="font-bold">Error!</strong>
        <span class="block sm:inline ml-2">${e.message}</span>
        <span class="absolute top-0 bottom-0 right-0 px-4 py-3 cursor-pointer" onclick="this.parentElement.remove()">
          <svg class="fill-current h-6 w-6 text-red-500" role="button" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20"><title>Close</title><path d="M14.348 14.849a1.2 1.2 0 0 1-1.697 0L10 11.103l-2.651 3.746a1.2 1.2 0 0 1-1.697-1.697l3.746-2.651-3.746-2.651a1.2 1.2 0 0 1 1.697-1.697L10 8.897l2.651-3.746a1.2 1.2 0 0 1 1.697 1.697L11.103 10l3.746 2.651a1.2 1.2 0 0 1 0 1.698z"/></svg>
        </span>
      `;
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
```  
app/companies/page.tsx (New page for Company CRUD, similar to People page)

```tsx
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
      messageBox.innerHTML = `
        <strong class="font-bold">Error!</strong>
        <span class="block sm:inline ml-2">${e.message}</span>
        <span class="absolute top-0 bottom-0 right-0 px-4 py-3 cursor-pointer" onclick="this.parentElement.remove()">
          <svg class="fill-current h-6 w-6 text-red-500" role="button" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20"><title>Close</title><path d="M14.348 14.849a1.2 1.2 0 0 1-1.697 0L10 11.103l-2.651 3.746a1.2 1.2 0 0 1-1.697-1.697l3.746-2.651-3.746-2.651a1.2 1.2 0 0 1 1.697-1.697L10 8.897l2.651-3.746a1.2 1.2 0 0 1 1.697 1.697L11.103 10l3.746 2.651a1.2 1.2 0 0 1 0 1.698z"/></svg>
        </span>
      `;
      document.body.appendChild(messageBox);
      setTimeout(() => messageBox.remove(), 5000); // Auto-remove after 5 seconds
    }
  };

  const handleDelete = async (company: ICompany) => {
    // Use a custom confirmation modal instead of confirm()
    const confirmDelete = window.confirm(`Are you sure you want to delete ${company.name}?`);
    if (!confirmDelete) return;

    try {
      const res = await fetch(`/api/companies/${company._id}`, { method: 'DELETE' });
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
      messageBox.innerHTML = `
        <strong class="font-bold">Error!</strong>
        <span class="block sm:inline ml-2">${e.message}</span>
        <span class="absolute top-0 bottom-0 right-0 px-4 py-3 cursor-pointer" onclick="this.parentElement.remove()">
          <svg class="fill-current h-6 w-6 text-red-500" role="button" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20"><title>Close</title><path d="M14.348 14.849a1.2 1.2 0 0 1-1.697 0L10 11.103l-2.651 3.746a1.2 1.2 0 0 1-1.697-1.697l3.746-2.651-3.746-2.651a1.2 1.2 0 0 1 1.697-1.697L10 8.897l2.651-3.746a1.2 1.2 0 0 1 1.697 1.697L11.103 10l3.746 2.651a1.2 1.2 0 0 1 0 1.698z"/></svg>
        </span>
      `;
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
``` 
2.4. MongoDB Change Streams (No significant change in logic, but data structure flowing through will be new)

lib/db-change-stream.ts (No change from previous version)  
```typescript
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

```  
2.5. Redis Integration (No change)
lib/redis.ts (No change from previous version)
```typescript
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
```  
2.6. Redis Stream Consumer (No sifnificant change)
lib/redis-consumer.ts (No change from previous version)
```typescript  
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
```  
services/event-processor.ts (No change from previous version)
```typescript

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
```  
2.7. Frontend Pages
app/companies/page.tsx (Updated to use new ICompany and CompanyForm)
```tsx
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
      messageBox.innerHTML = `
        <strong class="font-bold">Error!</strong>
        <span class="block sm:inline ml-2">${e.message}</span>
        <span class="absolute top-0 bottom-0 right-0 px-4 py-3 cursor-pointer" onclick="this.parentElement.remove()">
          <svg class="fill-current h-6 w-6 text-red-500" role="button" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20"><title>Close</title><path d="M14.348 14.849a1.2 1.2 0 0 1-1.697 0L10 11.103l-2.651 3.746a1.2 1.2 0 0 1-1.697-1.697l3.746-2.651-3.746-2.651a1.2 1.2 0 0 1 1.697-1.697L10 8.897l2.651-3.746a1.2 1.2 0 0 1 1.697 1.697L11.103 10l3.746 2.651a1.2 1.2 0 0 1 0 1.698z"/></svg>
        </span>
      `;
      document.body.appendChild(messageBox);
      setTimeout(() => messageBox.remove(), 5000); // Auto-remove after 5 seconds
    }
  };

  const handleDelete = async (company: ICompany) => {
    // Use a custom confirmation modal instead of confirm()
    const confirmDelete = window.confirm(`Are you sure you want to delete ${company.name}?`);
    if (!confirmDelete) return;

    try {
      const res = await fetch(`/api/companies/${company._id}`, { method: 'DELETE' });
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
      messageBox.innerHTML = `
        <strong class="font-bold">Error!</strong>
        <span class="block sm:inline ml-2">${e.message}</span>
        <span class="absolute top-0 bottom-0 right-0 px-4 py-3 cursor-pointer" onclick="this.parentElement.remove()">
          <svg class="fill-current h-6 w-6 text-red-500" role="button" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20"><title>Close</title><path d="M14.348 14.849a1.2 1.2 0 0 1-1.697 0L10 11.103l-2.651 3.746a1.2 1.2 0 0 1-1.697-1.697l3.746-2.651-3.746-2.651a1.2 1.2 0 0 1 1.697-1.697L10 8.897l2.651-3.746a1.2 1.2 0 0 1 1.697 1.697L11.103 10l3.746 2.651a1.2 1.2 0 0 1 0 1.698z"/></svg>
        </span>
      `;
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
```  
3. Containerization with Docker Compose
docker-compose.yml (No change from previous version) 
```yaml
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
```  

Dockerfile (for Next.js app) (No change from previous version)
```dockerfile
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

```  
4. Environment Variables
.env.local  (at the root of your project) (No change from previous version)
MONGODB_URI=mongodb://admin:password@localhost:27017/mydatabase?authSource=admin&replicaSet=rs0
REDIS_URL=redis://localhost:6379

MONGO_INITDB_ROOT_USERNAME=admin
MONGO_INITDB_ROOT_PASSWORD=password

5. Steps to get app up and running
5.1. Prerequisites
* Prerequisites:
Docker Desktop: Install Docker Desktop (includes Docker Engine and Docker Compose) for your operating system.
Node.js & npm/yarn: Ensure you have Node.js (v20 or later) and npm/yarn installed to initialize the Next.js project.
Initialize Next.js Project:

Create a new Next.js project with TypeScript:






5. Steps to get this app up and running
Prerequisites:

Docker Desktop: Install Docker Desktop (includes Docker Engine and Docker Compose) for your operating system.
Node.js & npm/yarn: Ensure you have Node.js (v20 or later) and npm/yarn installed to initialize the Next.js project.
Initialize Next.js Project:

Create a new Next.js project with TypeScript:
Bash

npx create-next-app@latest my-fullstack-app --typescript --eslint --tailwind --app
cd my-fullstack-app
Install additional dependencies:
Bash

yarn add mongoose ioredis
yarn add -D @types/mongoose @types/ioredis
Create Project Files and Directories:

Follow the "Project Structure" section to create all the files and directories (app/, lib/, services/, types/, .env.local, docker-compose.yml, Dockerfile, mongo-init.js).
Copy and paste the code provided in sections 2 and 3 into their respective files. Ensure you replace the placeholder content with the provided code, especially for the updated Mongoose models and new UI components.
Configure .env.local:

Update the .env.local file with your desired MongoDB credentials and Redis connection string. Make sure MONGO_INITDB_ROOT_USERNAME and MONGO_INITDB_ROOT_PASSWORD in .env.local match what's set in docker-compose.yml.
Build and Run with Docker Compose:

Open your terminal in the root directory of your project (where docker-compose.yml is located).
Run the following command to build the images and start the services:
Bash

docker compose up --build
This command will:
Build the nextjs-app Docker image based on your Dockerfile.
Pull mongo:8.0 and redis:8.0.0-alpine images.
Start the MongoDB container, initialize the replica set, and wait for it to be healthy.
Start the Redis container and wait for it to be healthy.
Start the Next.js app container.
Verify Services:

Once all services are up, you should see logs from each container in your terminal.
Next.js App: The Next.js application should be accessible at http://localhost:3000.
MongoDB: You can connect to MongoDB from your host machine using mongosh (if installed) or a GUI tool like MongoDB Compass at mongodb://localhost:27017.
Redis: You can connect to Redis using redis-cli (if installed) at redis-cli -h localhost -p 6379.
Test Functionality:

Navigate to http://localhost:3000/people and http://localhost:3000/companies in your browser.
Use the UI to perform CRUD operations (Add, Edit, Delete) for People and Companies.
Observe Change Streams: Check the terminal where docker compose up is running. You should see console logs from lib/db-change-stream.ts indicating "Change detected in people" or "Change detected in companies" whenever you perform a CRUD operation.
Observe Redis Stream Publishing: Following the change detection logs, you should also see "Published to Redis Stream..." messages.
Observe Redis Stream Consumption: You should see logs from lib/redis-stream-consumer.ts like "Received event from la:people:sync:request..." and "Processing incoming event..." as it consumes and processes messages.
Troubleshooting:

If containers fail to start, check the docker compose logs for specific error messages.
Ensure your .env.local file is correctly configured and located at the project root.
If MongoDB change streams don't work, verify that the replica set was initiated correctly (check mongo-init.js and MongoDB container logs). You might need to docker compose down -v and docker compose up --build to ensure a clean start if there were issues with volume persistence.
For Redis connectivity, check firewall rules if you have any.
This comprehensive setup provides a robust full-stack Next.js application with MongoDB CRUD, real-time database change capturing, and event-driven architecture using Redis Streams, all containerized for easy deployment, now fully compliant with your specified JSON schemas.  

