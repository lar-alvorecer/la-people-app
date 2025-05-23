## Prmpt:  

As un expert in NextJS Framework, typescript and mondodb, write a fullstack app in NExtJS the follows the requrements below:

1. has options to maintain entirely (CRUD operations) for 2 colletions (People and Companies) into a mongodb no-sql database (latest stable version). The UI should be modern ofering a good user experience. The JSON schema for these 2 collections you can get from https://github.com/lar-alvorecer/la-people-app/blob/main/json_schemas/companies_schema.json and https://github.com/lar-alvorecer/la-people-app/blob/main/json_schemas/people_schema.json. 

2. It shoud capture any insert update,delete events in mongodb and send the essential data of each database transaction to a Redis stream addressed by service "redis-integration-db" in docker internal network  and queue "la:people:changes".

3. it also should subscribe to a cosumer group assigned to the queue la:people:sync:request, reads all event in this queue and proceess each one writing events in other queues cosumed by other microservices. the moment to bring events from this queue have to be optmized. Ideal scenario: read this quieue only if it has events to read.

4. this app should be containeraized using docker-compose.yml file.

5. uses always as possible the latest stable version for each part (fontend resources, backend ressources)

6. describe all steps to be executed to have this app up and running.  

7.  At the end, write a bash script to create the entire foder three and create all tha files into their respective folders.  

## Answer:  
Okay, this is a comprehensive full-stack application request! Let's break it down and build it step by step.

**Core Technologies:**

*   **Next.JS (v14+ with App Router):** For the full-stack framework.
*   **TypeScript:** For static typing.
*   **MongoDB (latest stable):** NoSQL database.
*   **Mongoose:** ODM for MongoDB.
*   **Redis (latest stable):** In-memory data store for streams.
*   **ioredis:** Node.js Redis client.
*   **Tailwind CSS:** For modern UI styling.
*   **React Hook Form & Zod:** For form handling and validation.
*   **Docker & Docker Compose:** For containerization.

**JSON Schemas (from provided links):**

*   **People:** `name`, `email`, `birthDate`, `address` (object), `phoneNumbers` (array), `companyId` (ObjectId reference).
*   **Companies:** `name`, `industry`, `foundedDate`, `address` (object), `contactEmail`, `website`.

---

**Let's structure the project:**

```
nextjs-mongo-redis-app/
├── .env.local                  # Local environment variables
├── .gitignore
├── docker-compose.yml
├── Dockerfile
├── next.config.mjs
├── package.json
├── tsconfig.json
├── postcss.config.js
├── tailwind.config.ts
├── README.md
├── public/
│   └── ... # static assets
├── src/
│   ├── app/
│   │   ├── api/
│   │   │   ├── companies/
│   │   │   │   ├── [id]/route.ts # GET (single), PUT, DELETE
│   │   │   │   └── route.ts      # GET (list), POST
│   │   │   ├── people/
│   │   │   │   ├── [id]/route.ts # GET (single), PUT, DELETE
│   │   │   │   └── route.ts      # GET (list), POST
│   │   ├── companies/
│   │   │   ├── page.tsx          # List companies
│   │   │   ├── new/page.tsx      # Create company form
│   │   │   └── [id]/edit/page.tsx # Edit company form
│   │   ├── people/
│   │   │   ├── page.tsx          # List people
│   │   │   ├── new/page.tsx      # Create person form
│   │   │   └── [id]/edit/page.tsx # Edit person form
│   │   ├── layout.tsx            # Root layout
│   │   └── page.tsx              # Home page
│   ├── components/
│   │   ├── ui/                   # Basic UI elements (Button, Input, Modal - can be from shadcn/ui or custom)
│   │   │   ├── button.tsx
│   │   │   ├── input.tsx
│   │   │   ├── label.tsx
│   │   │   ├── textarea.tsx
│   │   │   └── modal.tsx
│   │   ├── CompanyForm.tsx
│   │   ├── CompaniesTable.tsx
│   │   ├── PersonForm.tsx
│   │   ├── PeopleTable.tsx
│   │   └── Navbar.tsx
│   ├── lib/
│   │   ├── mongodb.ts            # MongoDB connection
│   │   ├── redis.ts              # Redis connection
│   │   ├── utils.ts              # Utility functions
│   │   └── actions.ts            # Server actions (optional alternative to API routes for mutations)
│   ├── models/
│   │   ├── Company.ts
│   │   └── Person.ts
│   ├── services/
│   │   ├── cdcService.ts         # MongoDB Change Data Capture service
│   │   └── redisConsumerService.ts # Redis Stream Consumer service
│   ├── types/
│   │   └── index.ts              # TypeScript interfaces/types
├── scripts/
│   └── setup_dev_env.sh        # Bash script to create folder structure and files
```

---

**Phase 1: Setup & Basic Structure**

1.  **Initialize Next.js Project:**
    ```bash
    npx create-next-app@latest nextjs-mongo-redis-app --typescript --tailwind --eslint --app --src-dir --import-alias "@/*"
    cd nextjs-mongo-redis-app
    ```

2.  **Install Dependencies:**
    ```bash
    npm install mongoose ioredis zod react-hook-form @heroicons/react clsx tailwind-merge
    npm install -D @types/mongoose
    ```

---

**Phase 2: Dockerization**

**`docker-compose.yml`:**
```yaml
version: '3.8'

services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "3000:3000"
    depends_on:
      - mongo
      - redis-integration-db
    environment:
      - MONGODB_URI=mongodb://mongo:27017/people_app
      - REDIS_HOST=redis-integration-db
      - REDIS_PORT=6379
      - NEXT_PUBLIC_API_BASE_URL=http://localhost:3000/api # For client-side fetching
      - NODE_ENV=development # or production
    volumes:
      - .:/app # Mount current directory to /app in container for dev
      - /app/node_modules # Don't mount host node_modules
      - /app/.next # Don't mount host .next
    restart: unless-stopped
    networks:
      - app-network

  mongo:
    image: mongo:latest
    ports:
      - "27017:27017"
    volumes:
      - mongo-data:/data/db
    networks:
      - app-network
    restart: unless-stopped

  redis-integration-db:
    image: redis:latest
    ports:
      - "6379:6379"
    command: redis-server --appendonly yes # Enable persistence for streams (optional but good practice)
    volumes:
      - redis-data:/data
    networks:
      - app-network
    restart: unless-stopped

volumes:
  mongo-data:
  redis-data:

networks:
  app-network:
    driver: bridge
```

**`Dockerfile`:**
```dockerfile
# 1. Install dependencies only when needed
FROM node:20-alpine AS deps
WORKDIR /app

# Install pnpm
RUN npm install -g pnpm

COPY package.json pnpm-lock.yaml* ./
RUN pnpm install --frozen-lockfile

# 2. Rebuild the source code only when needed
FROM node:20-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Next.js collects completely anonymous telemetry data about general usage.
# Learn more here: https://nextjs.org/telemetry
# Uncomment the following line in case you want to disable telemetry.
ENV NEXT_TELEMETRY_DISABLED 1

RUN pnpm build

# 3. Production image, copy all the files and run next
FROM node:20-alpine AS runner
WORKDIR /app

ENV NODE_ENV production
# Uncomment the following line in case you want to disable telemetry during runtime.
ENV NEXT_TELEMETRY_DISABLED 1

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public

# Automatically leverage output traces to reduce image size
# https://nextjs.org/docs/advanced-features/output-file-tracing
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000

ENV PORT 3000

CMD ["node", "server.js"]
```
*Note: The Dockerfile uses `pnpm`. If you stick with `npm`, adjust accordingly. I'll use `npm` in `package.json` for simplicity in the example files, but `pnpm` is excellent.*
*Self-correction: `next.config.mjs` needs `output: 'standalone'` for the Dockerfile above.*

**`next.config.mjs`:**
```javascript
/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone', // Important for Docker optimized build
  experimental: {
    // Required for Change Streams and Redis Consumer long-running processes
    // This is a bit of a hack for Next.js. Ideally, these would be separate microservices.
    // We'll initialize them in a global setup that runs on server start.
    serverComponentsExternalPackages: ['mongoose', 'ioredis'],
  },
};

export default nextConfig;
```

**`.env.local` (create this file):**
```env
MONGODB_URI=mongodb://localhost:27017/people_app
REDIS_HOST=localhost
REDIS_PORT=6379
NEXT_PUBLIC_API_BASE_URL=http://localhost:3000/api

# For Change Stream and Consumer to run, they need to be initialized.
# This variable will be used in a global setup file.
INITIALIZE_BACKGROUND_SERVICES=true
```

---

**Phase 3: Backend - MongoDB & Models**

**`src/lib/mongodb.ts`:**
```typescript
import mongoose from 'mongoose';

const MONGODB_URI = process.env.MONGODB_URI!;

if (!MONGODB_URI) {
  throw new Error('Please define the MONGODB_URI environment variable inside .env.local');
}

interface MongooseCache {
  conn: typeof mongoose | null;
  promise: Promise<typeof mongoose> | null;
}

// Extend global to include mongoose cache
declare global {
  var mongoose: MongooseCache;
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
    cached.promise = mongoose.connect(MONGODB_URI, opts).then((mongooseInstance) => {
      console.log("MongoDB connected successfully.");
      return mongooseInstance;
    }).catch(err => {
      console.error("MongoDB connection error:", err);
      throw err;
    });
  }
  try {
    cached.conn = await cached.promise;
  } catch (e) {
    cached.promise = null;
    throw e;
  }

  return cached.conn;
}

export default dbConnect;
```

**`src/models/Company.ts`:**
```typescript
import mongoose, { Document, Model, Schema } from 'mongoose';

export interface ICompanyAddress {
  street: string;
  city: string;
  state: string;
  postalCode: string;
  country: string;
}

export interface ICompany extends Document {
  name: string;
  industry?: string;
  foundedDate?: Date;
  address?: ICompanyAddress;
  contactEmail: string;
  website?: string;
  createdAt: Date;
  updatedAt: Date;
}

const CompanyAddressSchema = new Schema<ICompanyAddress>({
  street: { type: String, required: true },
  city: { type: String, required: true },
  state: { type: String, required: true },
  postalCode: { type: String, required: true },
  country: { type: String, required: true },
}, { _id: false });

const CompanySchema = new Schema<ICompany>({
  name: { type: String, required: true, unique: true, trim: true },
  industry: { type: String, trim: true },
  foundedDate: { type: Date },
  address: { type: CompanyAddressSchema },
  contactEmail: { type: String, required: true, unique: true, trim: true, lowercase: true },
  website: { type: String, trim: true },
}, { timestamps: true });

// Ensure virtuals are included in toJSON/toObject
CompanySchema.set('toJSON', {
  virtuals: true,
  transform: (doc, ret) => {
    delete ret._id;
    delete ret.__v;
  }
});

const Company: Model<ICompany> = mongoose.models.Company || mongoose.model<ICompany>('Company', CompanySchema);

export default Company;
```

**`src/models/Person.ts`:**
```typescript
import mongoose, { Document, Model, Schema } from 'mongoose';
import { ICompanyAddress } from './Company'; // Re-use address if similar or define new

export interface IPersonAddress extends ICompanyAddress {} // Assuming same structure

export interface IPerson extends Document {
  name: string;
  email: string;
  birthDate?: Date;
  address?: IPersonAddress;
  phoneNumbers?: string[];
  companyId?: mongoose.Types.ObjectId | ICompany; // Populate with Company
  createdAt: Date;
  updatedAt: Date;
}

const PersonAddressSchema = new Schema<IPersonAddress>({
  street: { type: String, required: true },
  city: { type: String, required: true },
  state: { type: String, required: true },
  postalCode: { type: String, required: true },
  country: { type: String, required: true },
}, { _id: false });

const PersonSchema = new Schema<IPerson>({
  name: { type: String, required: true, trim: true },
  email: { type: String, required: true, unique: true, trim: true, lowercase: true },
  birthDate: { type: Date },
  address: { type: PersonAddressSchema },
  phoneNumbers: [{ type: String, trim: true }],
  companyId: { type: Schema.Types.ObjectId, ref: 'Company' },
}, { timestamps: true });

// Ensure virtuals are included in toJSON/toObject
PersonSchema.set('toJSON', {
  virtuals: true,
  transform: (doc, ret) => {
    delete ret._id;
    delete ret.__v;
  }
});


const Person: Model<IPerson> = mongoose.models.Person || mongoose.model<IPerson>('Person', PersonSchema);

export default Person;
```

---

**Phase 4: Backend - API Routes (CRUD)**

We'll create API routes for `People` and `Companies`. I'll show `People` in detail, `Companies` will be very similar.

**`src/app/api/people/route.ts`:**
```typescript
import { NextRequest, NextResponse } from 'next/server';
import dbConnect from '@/lib/mongodb';
import Person, { IPerson } from '@/models/Person';
import Company from '@/models/Company'; // Import Company to ensure it's registered for population

export async function GET(req: NextRequest) {
  await dbConnect();
  // Ensure Company model is initialized if populate is used
  await Company.countDocuments();


  try {
    const { searchParams } = new URL(req.url);
    const page = parseInt(searchParams.get('page') || '1', 10);
    const limit = parseInt(searchParams.get('limit') || '10', 10);
    const skip = (page - 1) * limit;

    const people = await Person.find({})
      .populate('companyId', 'name') // Populate company name
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit)
      .lean(); // Use .lean() for better performance if not modifying docs

    const totalPeople = await Person.countDocuments();
    
    return NextResponse.json({ 
      success: true, 
      data: people,
      pagination: {
        currentPage: page,
        totalPages: Math.ceil(totalPeople / limit),
        totalItems: totalPeople,
        itemsPerPage: limit
      }
    });
  } catch (error: any) {
    return NextResponse.json({ success: false, error: error.message }, { status: 500 });
  }
}

export async function POST(req: NextRequest) {
  await dbConnect();
  try {
    const body: Omit<IPerson, '_id' | 'createdAt' | 'updatedAt'> = await req.json();
    
    // Basic validation (use Zod for more robust validation)
    if (!body.name || !body.email) {
      return NextResponse.json({ success: false, error: "Name and email are required" }, { status: 400 });
    }
    // You can add Zod validation here
    const newPerson = await Person.create(body);
    return NextResponse.json({ success: true, data: newPerson }, { status: 201 });
  } catch (error: any) {
    if (error.code === 11000) { // Duplicate key error
        return NextResponse.json({ success: false, error: 'Email already exists.' }, { status: 409 });
    }
    return NextResponse.json({ success: false, error: error.message }, { status: 400 });
  }
}
```

**`src/app/api/people/[id]/route.ts`:**
```typescript
import { NextRequest, NextResponse } from 'next/server';
import dbConnect from '@/lib/mongodb';
import Person, { IPerson } from '@/models/Person';
import Company from '@/models/Company'; // For population

export async function GET(req: NextRequest, { params }: { params: { id: string } }) {
  await dbConnect();
  await Company.countDocuments(); // Ensure Company model is initialized for population

  try {
    const person = await Person.findById(params.id).populate('companyId', 'name').lean();
    if (!person) {
      return NextResponse.json({ success: false, error: 'Person not found' }, { status: 404 });
    }
    return NextResponse.json({ success: true, data: person });
  } catch (error: any) {
    return NextResponse.json({ success: false, error: error.message }, { status: 500 });
  }
}

export async function PUT(req: NextRequest, { params }: { params: { id: string } }) {
  await dbConnect();
  try {
    const body: Partial<Omit<IPerson, '_id' | 'createdAt' | 'updatedAt'>> = await req.json();
    
    // Handle empty string for companyId (means unassign company)
    if (body.companyId === '') {
        body.companyId = undefined;
    }

    const updatedPerson = await Person.findByIdAndUpdate(params.id, body, {
      new: true,
      runValidators: true,
    });
    if (!updatedPerson) {
      return NextResponse.json({ success: false, error: 'Person not found' }, { status: 404 });
    }
    return NextResponse.json({ success: true, data: updatedPerson });
  } catch (error: any) {
     if (error.code === 11000) { // Duplicate key error
        return NextResponse.json({ success: false, error: 'Email already exists for another person.' }, { status: 409 });
    }
    return NextResponse.json({ success: false, error: error.message }, { status: 400 });
  }
}

export async function DELETE(req: NextRequest, { params }: { params: { id: string } }) {
  await dbConnect();
  try {
    const deletedPerson = await Person.findByIdAndDelete(params.id);
    if (!deletedPerson) {
      return NextResponse.json({ success: false, error: 'Person not found' }, { status: 404 });
    }
    return NextResponse.json({ success: true, data: { id: params.id, message: 'Person deleted' } });
  } catch (error: any) {
    return NextResponse.json({ success: false, error: error.message }, { status: 500 });
  }
}
```
**API routes for `companies` (`src/app/api/companies/route.ts` and `src/app/api/companies/[id]/route.ts`) would be very similar, just replacing `Person` with `Company` and `IPerson` with `ICompany`.**

---

**Phase 5: Backend - Redis & Change Data Capture (CDC)**

**`src/lib/redis.ts`:**
```typescript
import Redis, { RedisOptions } from 'ioredis';

const REDIS_HOST = process.env.REDIS_HOST || 'localhost';
const REDIS_PORT = parseInt(process.env.REDIS_PORT || '6379', 10);

const redisOptions: RedisOptions = {
  host: REDIS_HOST,
  port: REDIS_PORT,
  maxRetriesPerRequest: null, // Important for long-running connections
  enableReadyCheck: false, // For some environments
};

let redisClient: Redis | null = null;
let publisherClient: Redis | null = null; // For CDC
let consumerClient: Redis | null = null; // For Stream Consumer

export function getRedisInstance(): Redis {
  if (!redisClient) {
    redisClient = new Redis(redisOptions);
    redisClient.on('error', (err) => console.error('Redis Client Error', err));
    redisClient.on('connect', () => console.log('Redis Client Connected'));
  }
  return redisClient;
}

export function getRedisPublisher(): Redis {
  if (!publisherClient) {
    publisherClient = new Redis(redisOptions);
    publisherClient.on('error', (err) => console.error('Redis Publisher Error', err));
    publisherClient.on('connect', () => console.log('Redis Publisher Connected'));
  }
  return publisherClient;
}

export function getRedisConsumer(): Redis {
   if (!consumerClient) {
    consumerClient = new Redis(redisOptions);
    consumerClient.on('error', (err) => console.error('Redis Consumer Error', err));
    consumerClient.on('connect', () => console.log('Redis Consumer Connected'));
  }
  return consumerClient;
}


// Graceful shutdown
const cleanup = async () => {
  if (redisClient) await redisClient.quit();
  if (publisherClient) await publisherClient.quit();
  if (consumerClient) await consumerClient.quit();
  console.log('Redis clients disconnected.');
  process.exit(0);
};

process.on('SIGINT', cleanup);
process.on('SIGTERM', cleanup);
```

**`src/services/cdcService.ts`:**
```typescript
import mongoose from 'mongoose';
import { getRedisPublisher } from '@/lib/redis';
import Person from '@/models/Person';
import Company from '@/models/Company';
import dbConnect from '@/lib/mongodb';

const REDIS_CHANGES_STREAM_KEY = 'la:people:changes';
let changeStreamInitialized = false;

async function publishChangeEvent(operationType: string, collectionName: string, documentId: string, data: any) {
  const redis = getRedisPublisher();
  const eventData = {
    operationType,
    collectionName,
    documentId: documentId.toString(),
    timestamp: new Date().toISOString(),
    data: data ? JSON.stringify(data) : '{}', // Ensure data is stringified
  };

  try {
    // XADD streamName * field1 value1 field2 value2 ...
    // Using an array of key-value pairs
    const messageArgs: string[] = [];
    for (const [key, value] of Object.entries(eventData)) {
        messageArgs.push(key, String(value)); // All values must be strings for XADD
    }
    await redis.xadd(REDIS_CHANGES_STREAM_KEY, '*', ...messageArgs);
    console.log(`CDC Event Published to ${REDIS_CHANGES_STREAM_KEY}:`, eventData);
  } catch (error) {
    console.error('Error publishing CDC event to Redis:', error);
  }
}

export async function initializeChangeStreams() {
  if (changeStreamInitialized || process.env.INITIALIZE_BACKGROUND_SERVICES !== 'true') {
    return;
  }
  
  await dbConnect(); // Ensure DB is connected
  const redis = getRedisPublisher(); // Ensure Redis publisher is connected

  console.log('Initializing MongoDB Change Streams...');

  const collectionsToWatch = [
    { model: Person, name: 'people' },
    { model: Company, name: 'companies' },
  ];

  collectionsToWatch.forEach(collInfo => {
    const changeStream = collInfo.model.watch([], { fullDocument: 'updateLookup' }); // fullDocument: 'updateLookup' gets the full document on updates

    changeStream.on('change', (change) => {
      console.log(`Change detected in ${collInfo.name}:`, change.operationType);
      let documentId: string;
      let relevantData: any = {};

      switch (change.operationType) {
        case 'insert':
          documentId = change.fullDocument._id.toString();
          relevantData = change.fullDocument;
          break;
        case 'update':
          documentId = change.documentKey._id.toString();
          relevantData = { 
            updatedFields: change.updateDescription.updatedFields,
            removedFields: change.updateDescription.removedFields,
            fullDocumentAfterUpdate: change.fullDocument // This is the key!
          };
          break;
        case 'delete':
          documentId = change.documentKey._id.toString();
          // For delete, fullDocument is not available in the change event itself by default
          // We only have the _id. The consumer would need to handle this (e.g., mark as deleted).
          relevantData = { documentId };
          break;
        case 'replace': // e.g. findOneAndReplace
            documentId = change.documentKey._id.toString();
            relevantData = change.fullDocument;
            break;
        default:
          console.log('Unhandled change type:', change.operationType);
          return;
      }
      publishChangeEvent(change.operationType, collInfo.name, documentId, relevantData);
    });

    changeStream.on('error', (error) => {
      console.error(`Error in ${collInfo.name} change stream:`, error);
      // Consider re-initializing or specific error handling logic here
    });
  });

  console.log('MongoDB Change Streams initialized for People and Companies.');
  changeStreamInitialized = true;
}
```

---

**Phase 6: Backend - Redis Stream Consumer**

**`src/services/redisConsumerService.ts`:**
```typescript
import { getRedisConsumer } from '@/lib/redis';

const SYNC_REQUEST_STREAM_KEY = 'la:people:sync:request';
const CONSUMER_GROUP_NAME = 'app-group'; // Your consumer group name
const CONSUMER_NAME = `consumer-${process.pid}`; // Unique consumer name per instance

let consumerInitialized = false;

// Function to create the consumer group (idempotent)
async function createConsumerGroup(redis: ReturnType<typeof getRedisConsumer>) {
  try {
    // XGROUP CREATE stream_key group_name $ MKSTREAM
    // MKSTREAM creates the stream if it doesn't exist
    await redis.xgroup('CREATE', SYNC_REQUEST_STREAM_KEY, CONSUMER_GROUP_NAME, '0', 'MKSTREAM');
    console.log(`Consumer group ${CONSUMER_GROUP_NAME} created or already exists for stream ${SYNC_REQUEST_STREAM_KEY}.`);
  } catch (error: any) {
    if (error.message.includes('BUSYGROUP')) {
      console.log(`Consumer group ${CONSUMER_GROUP_NAME} already exists for stream ${SYNC_REQUEST_STREAM_KEY}.`);
    } else {
      console.error(`Error creating consumer group ${CONSUMER_GROUP_NAME}:`, error);
      throw error; // Re-throw if it's not a BUSYGROUP error
    }
  }
}

async function processMessage(messageId: string, messageData: string[]) {
  console.log(`[${CONSUMER_NAME}] Processing message ${messageId} from ${SYNC_REQUEST_STREAM_KEY}:`);
  const parsedData: Record<string, string> = {};
  for (let i = 0; i < messageData.length; i += 2) {
    parsedData[messageData[i]] = messageData[i + 1];
  }
  console.log('Parsed Data:', parsedData);

  // TODO: Implement your logic to process the event and write to other queues
  // Example:
  // const targetQueue = `target:service:${parsedData.entityType}`;
  // const payload = { ...parsedData, processedAt: new Date().toISOString() };
  // await getRedisConsumer().xadd(targetQueue, '*', 'payload', JSON.stringify(payload));
  // console.log(`Event forwarded to queue: ${targetQueue}`);

  // Simulate processing
  await new Promise(resolve => setTimeout(resolve, 100)); 
  console.log(`[${CONSUMER_NAME}] Finished processing message ${messageId}`);
}

async function consumeMessages() {
  if (process.env.INITIALIZE_BACKGROUND_SERVICES !== 'true') return;

  const redis = getRedisConsumer();
  await createConsumerGroup(redis);

  console.log(`[${CONSUMER_NAME}] Starting to listen to stream ${SYNC_REQUEST_STREAM_KEY} in group ${CONSUMER_GROUP_NAME}...`);

  while (true) {
    try {
      // XREADGROUP GROUP group_name consumer_name [COUNT count] [BLOCK milliseconds] STREAMS key [key ...] id [id ...]
      // Using '>' to read new messages that arrive after joining the group.
      // BLOCK 0 means block indefinitely. Use a timeout (e.g., 5000ms) for graceful shutdown or periodic checks.
      const response = await redis.xreadgroup(
        'GROUP', CONSUMER_GROUP_NAME, CONSUMER_NAME,
        'COUNT', '10', // Read up to 10 messages at a time
        'BLOCK', '5000', // Block for 5 seconds if no messages
        'STREAMS', SYNC_REQUEST_STREAM_KEY, '>'
      );

      if (response) {
        // response is an array of [streamName, messagesArray]
        // e.g., [ [ 'la:people:sync:request', [ ['messageId1', ['field1', 'val1']], ['messageId2', ['field2', 'val2']] ] ] ]
        for (const streamMessages of response) {
          const streamName = streamMessages[0];
          const messages = streamMessages[1] as [string, string[]][]; // Type assertion

          if (messages.length === 0) continue;
          console.log(`[${CONSUMER_NAME}] Received ${messages.length} messages from ${streamName}`);

          const messageIdsToAck: string[] = [];
          for (const [messageId, messageData] of messages) {
            await processMessage(messageId, messageData);
            messageIdsToAck.push(messageId);
          }

          // Acknowledge messages
          if (messageIdsToAck.length > 0) {
            await redis.xack(SYNC_REQUEST_STREAM_KEY, CONSUMER_GROUP_NAME, ...messageIdsToAck);
            console.log(`[${CONSUMER_NAME}] Acknowledged ${messageIdsToAck.length} messages.`);
          }
        }
      } else {
        // console.log(`[${CONSUMER_NAME}] No messages received from ${SYNC_REQUEST_STREAM_KEY}, waiting...`);
      }
    } catch (error) {
      console.error(`[${CONSUMER_NAME}] Error reading from stream ${SYNC_REQUEST_STREAM_KEY}:`, error);
      // Implement retry logic or error handling (e.g., delay before retrying)
      await new Promise(resolve => setTimeout(resolve, 5000)); // Wait 5s before retrying
    }
  }
}

export async function initializeRedisConsumer() {
  if (consumerInitialized || process.env.INITIALIZE_BACKGROUND_SERVICES !== 'true') {
    return;
  }
  consumerInitialized = true;
  console.log('Initializing Redis Stream Consumer...');
  consumeMessages().catch(err => {
    console.error('Redis consumer loop exited with error:', err);
    // Potentially restart or log critical failure
  });
}
```

**`src/app/layout.tsx` (to initialize background services):**
```tsx
import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";
import Navbar from "@/components/Navbar";

// Background service initializers - these will run ONCE on server start in dev or when server starts in prod.
// This is a bit of a workaround for Next.js. Ideally, these would be separate services.
import { initializeChangeStreams } from "@/services/cdcService";
import { initializeRedisConsumer } from "@/services/redisConsumerService";

const inter = Inter({ subsets: ["latin"] });

export const metadata: Metadata = {
  title: "People & Companies App",
  description: "Manage People and Companies with MongoDB and Redis",
};

// Initialize background services if the flag is set
// This code runs on the server side when the app starts up.
if (process.env.INITIALIZE_BACKGROUND_SERVICES === 'true') {
  console.log("Attempting to initialize background services from layout...");
  // Use a self-invoking async function to call the initializers
  (async () => {
    try {
      // It's important these functions are idempotent and check if already initialized.
      await initializeChangeStreams();
      await initializeRedisConsumer();
      console.log("Background services initialization routines called.");
    } catch (error) {
      console.error("Error initializing background services from layout:", error);
    }
  })();
} else {
  console.log("Skipping background service initialization (INITIALIZE_BACKGROUND_SERVICES not true).");
}


export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className={`${inter.className} bg-gray-100 min-h-screen`}>
        <Navbar />
        <main className="container mx-auto p-4">
          {children}
        </main>
      </body>
    </html>
  );
}
```
**Important Note on Background Services:**
Placing initialization logic in `layout.tsx` is a common way to run server-side code once when the Next.js server starts for a long-running instance. However, for serverless deployments (like Vercel default), this initialization would happen on each cold start of a function, which is not suitable for persistent listeners. For true persistent background tasks in a serverless context, you'd use specialized services (e.g., Vercel Cron Jobs for polling, or separate worker deployments if continuous listening is needed). This example assumes a long-running server container.

---

**Phase 7: Frontend - UI Components & Pages**

This part will be extensive. I'll provide skeletons and key logic. You'll need to flesh out the forms and tables with Tailwind CSS.

**`src/types/index.ts`:**
```typescript
import { ICompany as MongoCompany, ICompanyAddress } from '@/models/Company';
import { IPerson as MongoPerson, IPersonAddress } from '@/models/Person';

// Frontend-friendly types (e.g., _id as id, dates as strings)
export interface Company extends Omit<MongoCompany, '_id' | 'createdAt' | 'updatedAt' | 'foundedDate'> {
  id: string;
  foundedDate?: string; // string for form input
  createdAt: string;
  updatedAt: string;
}

export interface Person extends Omit<MongoPerson, '_id' | 'createdAt' | 'updatedAt' | 'birthDate' | 'companyId'> {
  id: string;
  birthDate?: string; // string for form input
  companyId?: string; // ObjectId as string
  company?: { id: string; name: string }; // For populated data
  createdAt: string;
  updatedAt: string;
}

export type { ICompanyAddress, IPersonAddress };

export interface PaginatedResponse<T> {
  success: boolean;
  data: T[];
  pagination: {
    currentPage: number;
    totalPages: number;
    totalItems: number;
    itemsPerPage: number;
  };
  error?: string;
}
```

**Basic UI Components (examples - `src/components/ui/`)**
You can install `shadcn/ui` or build these simple ones:

**`src/components/ui/button.tsx`:**
```tsx
import React from 'react';
import { clsx } from 'clsx';

interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'default' | 'destructive' | 'outline' | 'secondary' | 'ghost' | 'link';
  size?: 'default' | 'sm' | 'lg' | 'icon';
}

const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant = 'default', size = 'default', ...props }, ref) => {
    const variants = {
      default: 'bg-blue-600 text-white hover:bg-blue-700',
      destructive: 'bg-red-600 text-white hover:bg-red-700',
      outline: 'border border-gray-300 hover:bg-gray-100',
      secondary: 'bg-gray-200 text-gray-800 hover:bg-gray-300',
      ghost: 'hover:bg-gray-100',
      link: 'text-blue-600 underline-offset-4 hover:underline',
    };
    const sizes = {
      default: 'h-10 px-4 py-2',
      sm: 'h-9 rounded-md px-3',
      lg: 'h-11 rounded-md px-8',
      icon: 'h-10 w-10',
    };
    return (
      <button
        className={clsx(
          'inline-flex items-center justify-center rounded-md text-sm font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:opacity-50 disabled:pointer-events-none',
          variants[variant],
          sizes[size],
          className
        )}
        ref={ref}
        {...props}
      />
    );
  }
);
Button.displayName = 'Button';
export { Button };
```
*(Create similar simple wrappers or use a library for `Input`, `Label`, `Textarea`)*

**`src/components/Navbar.tsx`:**
```tsx
import Link from 'next/link';

export default function Navbar() {
  return (
    <nav className="bg-gray-800 text-white p-4 shadow-md">
      <div className="container mx-auto flex justify-between items-center">
        <Link href="/" className="text-xl font-bold hover:text-gray-300">
          PeopleApp
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
  );
}
```

**`src/app/page.tsx` (Home):**
```tsx
export default function HomePage() {
  return (
    <div className="text-center py-10">
      <h1 className="text-4xl font-bold mb-4">Welcome to the People & Companies App</h1>
      <p className="text-lg text-gray-700">
        Manage your contacts and organizations efficiently.
      </p>
    </div>
  );
}
```

**Example: People Management (`src/app/people/page.tsx`, `src/components/PeopleTable.tsx`, `src/app/people/new/page.tsx`, `src/components/PersonForm.tsx` etc.)**

**`src/components/PeopleTable.tsx`:**
```tsx
'use client';
import Link from 'next/link';
import { Person } from '@/types';
import { Button } from '@/components/ui/button';
import { TrashIcon, PencilIcon } from '@heroicons/react/24/outline';

interface PeopleTableProps {
  people: Person[];
  onDelete: (id: string) => Promise<void>;
}

export default function PeopleTable({ people, onDelete }: PeopleTableProps) {
  if (!people || people.length === 0) {
    return <p className="text-gray-600">No people found.</p>;
  }

  return (
    <div className="overflow-x-auto bg-white shadow-md rounded-lg">
      <table className="min-w-full divide-y divide-gray-200">
        <thead className="bg-gray-50">
          <tr>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Name</th>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Email</th>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Company</th>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
          </tr>
        </thead>
        <tbody className="bg-white divide-y divide-gray-200">
          {people.map((person) => (
            <tr key={person.id}>
              <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">{person.name}</td>
              <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{person.email}</td>
              <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{person.company?.name || 'N/A'}</td>
              <td className="px-6 py-4 whitespace-nowrap text-sm font-medium space-x-2">
                <Link href={`/people/${person.id}/edit`} passHref>
                  <Button variant="outline" size="sm" className="text-blue-600 border-blue-600 hover:bg-blue-50">
                    <PencilIcon className="h-4 w-4 mr-1" /> Edit
                  </Button>
                </Link>
                <Button
                  variant="destructive"
                  size="sm"
                  onClick={() => onDelete(person.id)}
                  className="text-red-600 border-red-600 hover:bg-red-50 bg-transparent"
                >
                  <TrashIcon className="h-4 w-4 mr-1" /> Delete
                </Button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
```

**`src/app/people/page.tsx` (List People):**
```tsx
'use client'; // Required for useState, useEffect, event handlers

import { useState, useEffect, useCallback } from 'react';
import Link from 'next/link';
import PeopleTable from '@/components/PeopleTable';
import { Button } from '@/components/ui/button';
import { Person, PaginatedResponse } from '@/types';

const API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL;

export default function PeoplePage() {
  const [people, setPeople] = useState<Person[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [pagination, setPagination] = useState({ currentPage: 1, totalPages: 1, itemsPerPage: 10});

  const fetchPeople = useCallback(async (page = 1, limit = 10) => {
    setIsLoading(true);
    setError(null);
    try {
      const response = await fetch(`${API_BASE_URL}/people?page=${page}&limit=${limit}`);
      if (!response.ok) {
        throw new Error(`Failed to fetch people: ${response.statusText}`);
      }
      const result: PaginatedResponse<Person> = await response.json();
      if (result.success) {
        setPeople(result.data);
        setPagination(result.pagination);
      } else {
        throw new Error(result.error || 'Unknown error fetching people');
      }
    } catch (err: any) {
      setError(err.message);
      setPeople([]);
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchPeople(pagination.currentPage, pagination.itemsPerPage);
  }, [fetchPeople, pagination.currentPage, pagination.itemsPerPage]);

  const handleDeletePerson = async (id: string) => {
    if (!confirm('Are you sure you want to delete this person?')) return;
    try {
      const response = await fetch(`${API_BASE_URL}/people/${id}`, { method: 'DELETE' });
      if (!response.ok) {
        const errData = await response.json();
        throw new Error(errData.error || 'Failed to delete person');
      }
      // Re-fetch or filter out locally
      setPeople(prevPeople => prevPeople.filter(p => p.id !== id));
      alert('Person deleted successfully');
    } catch (err: any) {
      setError(err.message);
      alert(`Error: ${err.message}`);
    }
  };
  
  const handlePageChange = (newPage: number) => {
    if (newPage >= 1 && newPage <= pagination.totalPages) {
      setPagination(prev => ({ ...prev, currentPage: newPage }));
    }
  };


  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h1 className="text-3xl font-bold text-gray-800">People</h1>
        <Link href="/people/new" passHref>
          <Button>Add New Person</Button>
        </Link>
      </div>

      {isLoading && <p className="text-gray-600">Loading people...</p>}
      {error && <p className="text-red-500 bg-red-100 p-3 rounded-md">Error: {error}</p>}
      
      {!isLoading && !error && (
        <>
          <PeopleTable people={people} onDelete={handleDeletePerson} />
          {/* Pagination Controls */}
          {pagination.totalPages > 1 && (
            <div className="mt-4 flex justify-center items-center space-x-2">
              <Button 
                onClick={() => handlePageChange(pagination.currentPage - 1)} 
                disabled={pagination.currentPage === 1}
                variant="outline"
              >
                Previous
              </Button>
              <span>Page {pagination.currentPage} of {pagination.totalPages}</span>
              <Button 
                onClick={() => handlePageChange(pagination.currentPage + 1)} 
                disabled={pagination.currentPage === pagination.totalPages}
                variant="outline"
              >
                Next
              </Button>
            </div>
          )}
        </>
      )}
    </div>
  );
}
```
*You would create similar `page.tsx`, `Table.tsx`, `Form.tsx`, `new/page.tsx`, `[id]/edit/page.tsx` for **Companies**.*
*The Forms (`PersonForm.tsx`, `CompanyForm.tsx`) would use `react-hook-form` and `zod` for validation, fetching company lists for dropdowns, etc.* This part requires significant UI code.

---

**Phase 8: Running the Application**

1.  **Ensure Docker is running.**
2.  **Build and Start Containers:**
    ```bash
    docker-compose up --build
    ```
    (Use `-d` to run in detached mode: `docker-compose up --build -d`)
3.  **Access the App:** Open `http://localhost:3000` in your browser.
4.  **Check Logs:**
    ```bash
    docker-compose logs -f app
    docker-compose logs -f mongo
    docker-compose logs -f redis-integration-db
    ```
5.  **To test Redis Stream Consumer for `la:people:sync:request`:**
    You'll need to manually publish a message to this stream using `redis-cli` or another tool, as this app only consumes from it.
    ```bash
    docker-compose exec redis-integration-db redis-cli
    # Inside redis-cli:
    # XADD la:people:sync:request * type "user_sync" userId "123" details "{\"action\":\"full_sync\"}"
    ```
    Then check the `app` logs for the consumer processing it.

---

**Phase 9: Bash Script for Folder/File Creation**

**`scripts/setup_dev_env.sh`:**
```bash
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
```
**To use the script:**
1. Save it as `setup_dev_env.sh` in a directory *outside* your intended project directory.
2. Make it executable: `chmod +x setup_dev_env.sh`
3. Run it: `./setup_dev_env.sh`
4. It will create the `nextjs-mongo-redis-app` folder and the structure within.
5. Then, `cd nextjs-mongo-redis-app`.
6. **Crucially, initialize Next.js properly INSIDE this new directory to get all core files and dependencies set up correctly:**
   ```bash
   npx create-next-app@latest . --typescript --tailwind --eslint --app --src-dir --import-alias "@/*"
   ```
   When prompted, allow it to overwrite files like `package.json`, `tsconfig.json`, `tailwind.config.ts`, `next.config.mjs`, `postcss.config.js`, `.gitignore` and `src/app/layout.tsx`, `src/app/page.tsx`, `src/app/globals.css`.
7. Then, copy the content of the files generated by this detailed answer into their respective locations created by the script.
8. Install the additional specific dependencies: `npm install mongoose ioredis zod react-hook-form @heroicons/react clsx tailwind-merge` and `npm install -D @types/mongoose`.

This completes a very detailed plan and initial code for your application. The frontend UI (forms, complete tables, styling) will still require significant effort to make it "modern and good UX," but the backend logic and connections are laid out. Remember to replace placeholders and add robust error handling and validation where needed.  

---  

Please, write a Bash script to input all content in each file created into the project structure.

Okay, this is a very powerful script that will generate the entire project structure and populate all the files with the code we discussed.

**Important Considerations Before Running:**

1.  **Backup:** If you're running this in a directory that has important data, back it up. This script creates a new directory and writes many files.
2.  **Permissions:** You'll need to make the script executable (`chmod +x create_full_app.sh`).
3.  **Dependencies:** This script creates the `package.json`. After it runs, you'll need Node.js and npm (or pnpm/yarn if you modify it) installed to run `npm install`. Docker and Docker Compose are also needed to run the application.
4.  **Length & Potential Typos:** This script is very long. I've tried to be meticulous, but a small typo in a heredoc could cause issues. If you encounter problems, check the console output carefully for errors when the script runs.
5.  **Overwrite:** If the target directory (`nextjs-mongo-redis-app`) already exists, this script will write into it and potentially overwrite existing files with the same names.

Here's the `bash` script:

```bash
#!/bin/bash

PROJECT_NAME="nextjs-mongo-redis-app"

# Check if project directory already exists
if [ -d "$PROJECT_NAME" ]; then
  echo "Directory '$PROJECT_NAME' already exists."
  read -p "Do you want to overwrite or add files to it? (y/N): " confirm
  if [[ "$confirm" != [yY] && "$confirm" != [yY][eE][sS] ]]; then
    echo "Aborted by user."
    exit 1
  fi
else
  mkdir -p "$PROJECT_NAME"
  echo "Created directory '$PROJECT_NAME'."
fi

cd "$PROJECT_NAME" || { echo "Failed to cd into $PROJECT_NAME"; exit 1; }

echo "Creating project structure and files for '$PROJECT_NAME'..."

# --- Root Files ---

# .env.local
cat << 'EOF_ENV_LOCAL' > .env.local
MONGODB_URI=mongodb://localhost:27017/people_app
REDIS_HOST=localhost
REDIS_PORT=6379
NEXT_PUBLIC_API_BASE_URL=http://localhost:3000/api

# For Change Stream and Consumer to run, they need to be initialized.
# Set to true when running in a long-lived server environment (like the Docker container)
# Set to false or remove if deploying to serverless where background tasks are handled differently.
INITIALIZE_BACKGROUND_SERVICES=true
EOF_ENV_LOCAL
echo "Created .env.local"

# .gitignore
cat << 'EOF_GITIGNORE' > .gitignore
# See https://help.github.com/articles/ignoring-files/ for more about ignoring files.

# Dependencies
/node_modules
/.pnp
.pnp.js
.yarn/

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
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*
pnpm-debug.log*

# Local Env Files
.env
.env*.local
!.env.example

# IDE / Editor
.vscode/
.idea/
*.swp
*~
EOF_GITIGNORE
echo "Created .gitignore"

# docker-compose.yml
cat << 'EOF_DOCKER_COMPOSE' > docker-compose.yml
version: '3.8'

services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "3000:3000"
    depends_on:
      mongo:
        condition: service_healthy # Wait for mongo to be healthy
      redis-integration-db:
        condition: service_healthy # Wait for redis to be healthy
    environment:
      - MONGODB_URI=mongodb://mongo:27017/people_app
      - REDIS_HOST=redis-integration-db
      - REDIS_PORT=6379
      - NEXT_PUBLIC_API_BASE_URL=http://app:3000/api # Internal for server-side, adjust if client needs external
      - NODE_ENV=development # Change to production for prod builds
      - INITIALIZE_BACKGROUND_SERVICES=true # Ensure background services run in Docker
    volumes:
      - .:/app # Mount current directory to /app in container for dev
      - /app/node_modules # Don't mount host node_modules
      - /app/.next # Don't mount host .next
    restart: unless-stopped
    networks:
      - app-network
    healthcheck: # Optional: check if the Next.js app is responsive
      test: ["CMD", "curl", "-f", "http://localhost:3000/api/health"] # Add a /api/health endpoint
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s # Give time for app to start

  mongo:
    image: mongo:latest
    ports:
      - "27017:27017"
    volumes:
      - mongo-data:/data/db
      - ./mongo-init.js:/docker-entrypoint-initdb.d/mongo-init.js:ro # For replica set init
    networks:
      - app-network
    restart: unless-stopped
    command: mongod --replSet rs0 --bind_ip_all # Required for change streams
    healthcheck:
      test: echo 'db.runCommand("ping").ok' | mongosh localhost:27017/test --quiet
      interval: 10s
      timeout: 10s
      retries: 5
      start_period: 10s

  redis-integration-db:
    image: redis:latest
    ports:
      - "6379:6379"
    command: redis-server --appendonly yes
    volumes:
      - redis-data:/data
    networks:
      - app-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  mongo-data:
  redis-data:

networks:
  app-network:
    driver: bridge
EOF_DOCKER_COMPOSE
echo "Created docker-compose.yml"

# mongo-init.js (for replica set initialization, required for change streams)
cat << 'EOF_MONGO_INIT_JS' > mongo-init.js
try {
  rs.status();
  print("Replica set already initialized.");
} catch (e) {
  if (e.codeName === 'NotYetInitialized') {
    print("Initializing replica set...");
    rs.initiate({
      _id: "rs0",
      members: [
        { _id: 0, host: "mongo:27017" }
      ]
    });
    print("Replica set initialized.");

    // Wait for replica set to be ready (primary elected)
    let isMaster = false;
    let retries = 30; // Try for 30 seconds
    while (!isMaster && retries > 0) {
      print("Waiting for primary to be elected...");
      sleep(1000); // Sleep for 1 second (mongosh syntax)
      let status = rs.status();
      if (status.myState === 1) { // 1 indicates PRIMARY
        isMaster = true;
        print("Primary elected.");
      }
      retries--;
    }
    if (!isMaster) {
      print("Failed to elect primary in time.");
      // exit(1); // or throw error if critical
    }

  } else {
    print("Error checking replica set status: " + e);
    // throw e; // Re-throw other errors
  }
}
EOF_MONGO_INIT_JS
echo "Created mongo-init.js"


# Dockerfile
cat << 'EOF_DOCKERFILE' > Dockerfile
# 1. Install dependencies only when needed
FROM node:20-alpine AS deps
WORKDIR /app

COPY package.json package-lock.json* ./
# Use npm ci for faster, more reliable builds if package-lock.json is committed
# If package-lock.json might not exist, use npm install
RUN npm ci || npm install --legacy-peer-deps

# 2. Rebuild the source code only when needed
FROM node:20-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Next.js collects completely anonymous telemetry data about general usage.
# Learn more here: https://nextjs.org/telemetry
ENV NEXT_TELEMETRY_DISABLED 1

RUN npm run build

# 3. Production image, copy all the files and run next
FROM node:20-alpine AS runner
WORKDIR /app

ENV NODE_ENV production
ENV NEXT_TELEMETRY_DISABLED 1

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public

# Automatically leverage output traces to reduce image size
# https://nextjs.org/docs/advanced-features/output-file-tracing
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000
ENV PORT 3000

# Add a basic health check endpoint if you add one to your app
# CMD ["node", "server.js"] will be used by default with output: 'standalone'

CMD ["node", "server.js"]
EOF_DOCKERFILE
echo "Created Dockerfile"

# next.config.mjs
cat << 'EOF_NEXT_CONFIG' > next.config.mjs
/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone', // Important for Docker optimized build
  experimental: {
    // Required for Change Streams and Redis Consumer long-running processes
    // This allows these packages to be bundled correctly.
    serverComponentsExternalPackages: ['mongoose', 'ioredis'],
  },
  // If you need to ensure certain files are copied to standalone output
  // outputTraceIncludes: ['./src/services/**'], // Example
};

export default nextConfig;
EOF_NEXT_CONFIG
echo "Created next.config.mjs"

# package.json
cat << 'EOF_PACKAGE_JSON' > package.json
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
    "@heroicons/react": "^2.1.3",
    "clsx": "^2.1.0",
    "ioredis": "^5.4.1",
    "mongoose": "^8.3.2",
    "next": "14.2.3",
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "react-hook-form": "^7.51.4",
    "tailwind-merge": "^2.3.0",
    "zod": "^3.23.6"
  },
  "devDependencies": {
    "@types/mongoose": "^5.11.97",
    "@types/node": "^20.12.7",
    "@types/react": "^18.3.1",
    "@types/react-dom": "^18.3.0",
    "autoprefixer": "^10.4.19",
    "eslint": "^8.57.0",
    "eslint-config-next": "14.2.3",
    "postcss": "^8.4.38",
    "tailwindcss": "^3.4.3",
    "typescript": "^5.4.5"
  }
}
EOF_PACKAGE_JSON
echo "Created package.json"

# tsconfig.json
cat << 'EOF_TSCONFIG_JSON' > tsconfig.json
{
  "compilerOptions": {
    "target": "es5",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "forceConsistentCasingInFileNames": true,
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
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
EOF_TSCONFIG_JSON
echo "Created tsconfig.json"

# postcss.config.js
cat << 'EOF_POSTCSS_CONFIG' > postcss.config.js
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
EOF_POSTCSS_CONFIG
echo "Created postcss.config.js"

# tailwind.config.ts
cat << 'EOF_TAILWIND_CONFIG' > tailwind.config.ts
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
EOF_TAILWIND_CONFIG
echo "Created tailwind.config.ts"

# README.md
cat << 'EOF_README_MD' > README.md
# Next.js, MongoDB, and Redis Fullstack App

This application demonstrates CRUD operations for 'People' and 'Companies' collections in MongoDB,
with change data capture to a Redis stream, and a Redis stream consumer.

## Setup

1.  Ensure Docker and Docker Compose are installed.
2.  Ensure Node.js and npm (or pnpm/yarn) are installed.
3.  Run `npm install` (or your package manager's install command) to install dependencies.
4.  The `mongo-init.js` script will attempt to initialize a replica set for MongoDB, which is necessary for Change Streams.
5.  Build and start the services: `docker-compose up --build -d`.
    *   It might take a moment for MongoDB to initialize the replica set on the first run. Check `docker-compose logs mongo`.
6.  Access the app at `http://localhost:3000`.

## Features

-   CRUD for People (UI and API)
-   CRUD for Companies (UI and API)
-   MongoDB Change Data Capture (CDC) publishing events to Redis Stream `la:people:changes`.
-   Redis Stream Consumer listening to `la:people:sync:request` (consumer group `app-group`).

## Tech Stack

-   Next.js (v14+ with App Router)
-   TypeScript
-   MongoDB (latest stable) & Mongoose
-   Redis (latest stable) & ioredis
-   Tailwind CSS
-   React Hook Form & Zod (for frontend forms)
-   Docker & Docker Compose

## Testing Background Services

### MongoDB Change Data Capture (CDC)

1.  Perform any CRUD operation via the UI (e.g., add a new person).
2.  Check the application logs: `docker-compose logs -f app`. You should see "CDC Event Published..."
3.  You can also inspect the Redis stream directly:
    ```bash
    docker-compose exec redis-integration-db redis-cli
    # Inside redis-cli:
    XRANGE la:people:changes - +
    ```

### Redis Stream Consumer (`la:people:sync:request`)

This app *consumes* from this stream. To test it, you need to *publish* a message to it.

1.  Ensure the app is running (`docker-compose up -d`).
2.  Publish a message using `redis-cli`:
    ```bash
    docker-compose exec redis-integration-db redis-cli
    # Inside redis-cli:
    XADD la:people:sync:request * type "test_sync" entityId "E123" details "{\"action\":\"process_me\"}"
    ```
3.  Check the application logs: `docker-compose logs -f app`. You should see the consumer pick up and process this message.

## Environment Variables

Configure in `.env.local` (for local Next.js dev outside Docker) or in `docker-compose.yml` for the `app` service.

-   `MONGODB_URI`: MongoDB connection string.
-   `REDIS_HOST`: Redis host.
-   `REDIS_PORT`: Redis port.
-   `NEXT_PUBLIC_API_BASE_URL`: Base URL for client-side API calls.
-   `INITIALIZE_BACKGROUND_SERVICES`: Set to `true` to enable CDC and Redis consumer initialization.

## Notes

-   The MongoDB service in `docker-compose.yml` is configured to run as a single-node replica set (`rs0`) because MongoDB Change Streams require a replica set. The `mongo-init.js` script handles this initialization.
-   The background services (CDC listener, Redis consumer) are initialized within the Next.js application process. In a larger production system, these might be separate microservices.
EOF_README_MD
echo "Created README.md"

# --- src directory ---
mkdir -p src/app/api/companies/[id]
mkdir -p src/app/api/people/[id]
mkdir -p src/app/api/health # For health check
mkdir -p src/app/companies/new
mkdir -p src/app/companies/[id]/edit
mkdir -p src/app/people/new
mkdir -p src/app/people/[id]/edit
mkdir -p src/components/ui
mkdir -p src/lib
mkdir -p src/models
mkdir -p src/services
mkdir -p src/types
echo "Created src subdirectories"

# src/app/globals.css
cat << 'EOF_SRC_APP_GLOBALS_CSS' > src/app/globals.css
@tailwind base;
@tailwind components;
@tailwind utilities;

/* Add any global styles here */
body {
  @apply bg-slate-50 text-slate-800;
}
EOF_SRC_APP_GLOBALS_CSS
echo "Created src/app/globals.css"

# src/app/layout.tsx
cat << 'EOF_SRC_APP_LAYOUT_TSX' > src/app/layout.tsx
import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";
import Navbar from "@/components/Navbar";

// IMPORTANT: Conditional initialization for background services
// This ensures they only run on the server and ideally once per server instance.
if (typeof window === 'undefined' && process.env.INITIALIZE_BACKGROUND_SERVICES === 'true' && process.env.NODE_ENV !== 'production' || (process.env.NODE_ENV === 'production' && process.env.NEXT_RUNTIME !== 'edge')) {
  // Dynamically import and initialize to avoid issues during build or in client components
  (async () => {
    try {
      console.log("Layout: Attempting to initialize background services...");
      const { initializeChangeStreams } = await import("@/services/cdcService");
      const { initializeRedisConsumer } = await import("@/services/redisConsumerService");
      
      // These functions should be idempotent
      await initializeChangeStreams();
      await initializeRedisConsumer();
      console.log("Layout: Background services initialization sequence called.");
    } catch (error) {
      console.error("Layout: Error initializing background services:", error);
    }
  })();
} else if (typeof window === 'undefined') {
  console.log("Layout: Skipping background service initialization (INITIALIZE_BACKGROUND_SERVICES not true, or edge runtime, or prod build without specific check).");
}


const inter = Inter({ subsets: ["latin"] });

export const metadata: Metadata = {
  title: "People & Companies App",
  description: "Manage People and Companies with MongoDB and Redis",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className={`${inter.className} min-h-screen flex flex-col`}>
        <Navbar />
        <main className="container mx-auto p-4 flex-grow">
          {children}
        </main>
        <footer className="bg-gray-800 text-white text-center p-4">
          <p>&copy; 2024 PeopleApp Inc.</p>
        </footer>
      </body>
    </html>
  );
}
EOF_SRC_APP_LAYOUT_TSX
echo "Created src/app/layout.tsx"

# src/app/page.tsx
cat << 'EOF_SRC_APP_PAGE_TSX' > src/app/page.tsx
import Link from 'next/link';
import { Button } from '@/components/ui/button'; // Assuming Button component exists

export default function HomePage() {
  return (
    <div className="text-center py-10">
      <h1 className="text-4xl font-bold mb-6 text-gray-800">Welcome to PeopleApp</h1>
      <p className="text-lg text-gray-600 mb-8">
        Efficiently manage your people and company records.
      </p>
      <div className="space-x-4">
        <Link href="/people" passHref>
          <Button size="lg">Manage People</Button>
        </Link>
        <Link href="/companies" passHref>
          <Button size="lg" variant="secondary">Manage Companies</Button>
        </Link>
      </div>
      <div className="mt-12 p-6 bg-white shadow-lg rounded-lg">
        <h2 className="text-2xl font-semibold mb-3 text-gray-700">Key Features</h2>
        <ul className="list-disc list-inside text-left mx-auto max-w-md text-gray-600">
          <li>Full CRUD operations for People and Companies.</li>
          <li>Real-time database change tracking via MongoDB Change Streams.</li>
          <li>Integration with Redis for event-driven architecture.</li>
          <li>Responsive and modern user interface.</li>
          <li>Containerized with Docker for easy deployment.</li>
        </ul>
      </div>
    </div>
  );
}
EOF_SRC_APP_PAGE_TSX
echo "Created src/app/page.tsx"

# --- API Routes ---
# src/app/api/health/route.ts
cat << 'EOF_SRC_API_HEALTH_ROUTE_TS' > src/app/api/health/route.ts
import { NextResponse } from 'next/server';
import dbConnect from '@/lib/mongodb';
import { getRedisInstance } from '@/lib/redis';

export async function GET() {
  let dbStatus = 'disconnected';
  let redisStatus = 'disconnected';

  try {
    await dbConnect();
    // Basic check, like counting documents in a small collection or a ping
    // For simplicity, if dbConnect doesn't throw, we assume basic connectivity.
    // mongoose.connection.db.admin().ping() is more robust.
    if (dbConnect && global.mongoose?.conn?.readyState === 1) {
        dbStatus = 'connected';
    }
  } catch (error) {
    console.error("Health Check: MongoDB connection error", error);
    dbStatus = 'error';
  }

  try {
    const redis = getRedisInstance();
    const pingResponse = await redis.ping();
    if (pingResponse === "PONG") {
      redisStatus = 'connected';
    }
  } catch (error) {
    console.error("Health Check: Redis connection error", error);
    redisStatus = 'error';
  }

  const healthStatus = {
    status: 'ok',
    timestamp: new Date().toISOString(),
    mongodb: dbStatus,
    redis: redisStatus,
  };

  if (dbStatus !== 'connected' || redisStatus !== 'connected') {
    return NextResponse.json(healthStatus, { status: 503 }); // Service Unavailable
  }

  return NextResponse.json(healthStatus);
}
EOF_SRC_API_HEALTH_ROUTE_TS
echo "Created src/app/api/health/route.ts"

# src/app/api/companies/route.ts
cat << 'EOF_SRC_API_COMPANIES_ROUTE_TS' > src/app/api/companies/route.ts
import { NextRequest, NextResponse } from 'next/server';
import dbConnect from '@/lib/mongodb';
import Company, { ICompany } from '@/models/Company';
import { z } from 'zod';

// Zod schema for validation
const companySchema = z.object({
  name: z.string().min(1, "Name is required"),
  contactEmail: z.string().email("Invalid email format"),
  industry: z.string().optional(),
  foundedDate: z.string().optional().refine(val => !val || !isNaN(Date.parse(val)), {
    message: "Invalid date format for foundedDate",
  }),
  website: z.string().url().optional().or(z.literal('')),
  address: z.object({
    street: z.string().min(1, "Street is required"),
    city: z.string().min(1, "City is required"),
    state: z.string().min(1, "State is required"),
    postalCode: z.string().min(1, "Postal code is required"),
    country: z.string().min(1, "Country is required"),
  }).optional(),
});


export async function GET(req: NextRequest) {
  await dbConnect();
  try {
    const { searchParams } = new URL(req.url);
    const page = parseInt(searchParams.get('page') || '1', 10);
    const limit = parseInt(searchParams.get('limit') || '10', 10);
    const skip = (page - 1) * limit;

    const companies = await Company.find({})
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit)
      .lean();

    const totalCompanies = await Company.countDocuments();
    
    return NextResponse.json({ 
      success: true, 
      data: companies.map(c => ({...c, id: c._id.toString()})), // Ensure id is string
      pagination: {
        currentPage: page,
        totalPages: Math.ceil(totalCompanies / limit),
        totalItems: totalCompanies,
        itemsPerPage: limit
      }
    });
  } catch (error: any) {
    return NextResponse.json({ success: false, error: error.message }, { status: 500 });
  }
}

export async function POST(req: NextRequest) {
  await dbConnect();
  try {
    const body = await req.json();
    const validation = companySchema.safeParse(body);

    if (!validation.success) {
      return NextResponse.json({ success: false, error: "Validation failed", issues: validation.error.issues }, { status: 400 });
    }
    
    const newCompanyData: Partial<ICompany> = validation.data;
    if (validation.data.foundedDate) {
      newCompanyData.foundedDate = new Date(validation.data.foundedDate);
    }


    const newCompany = await Company.create(newCompanyData);
    return NextResponse.json({ success: true, data: {...newCompany.toObject(), id: newCompany._id.toString()} }, { status: 201 });
  } catch (error: any) {
    if (error.code === 11000) { // Duplicate key error
        const field = Object.keys(error.keyPattern)[0];
        return NextResponse.json({ success: false, error: `Company with this ${field} already exists.` }, { status: 409 });
    }
    return NextResponse.json({ success: false, error: error.message }, { status: 400 });
  }
}
EOF_SRC_API_COMPANIES_ROUTE_TS
echo "Created src/app/api/companies/route.ts"

# src/app/api/companies/[id]/route.ts
cat << 'EOF_SRC_API_COMPANIES_ID_ROUTE_TS' > src/app/api/companies/[id]/route.ts
import { NextRequest, NextResponse } from 'next/server';
import dbConnect from '@/lib/mongodb';
import Company, { ICompany } from '@/models/Company';
import Person from '@/models/Person'; // To handle company deletion impact
import { z } from 'zod';

// Zod schema for updates (all fields optional)
const companyUpdateSchema = z.object({
  name: z.string().min(1, "Name is required").optional(),
  contactEmail: z.string().email("Invalid email format").optional(),
  industry: z.string().optional(),
  foundedDate: z.string().optional().refine(val => !val || !isNaN(Date.parse(val)), {
    message: "Invalid date format for foundedDate",
  }),
  website: z.string().url().optional().or(z.literal('')),
  address: z.object({
    street: z.string().min(1, "Street is required"),
    city: z.string().min(1, "City is required"),
    state: z.string().min(1, "State is required"),
    postalCode: z.string().min(1, "Postal code is required"),
    country: z.string().min(1, "Country is required"),
  }).optional(),
}).partial(); // Makes all fields optional for PUT

export async function GET(req: NextRequest, { params }: { params: { id: string } }) {
  await dbConnect();
  try {
    const company = await Company.findById(params.id).lean();
    if (!company) {
      return NextResponse.json({ success: false, error: 'Company not found' }, { status: 404 });
    }
    return NextResponse.json({ success: true, data: {...company, id: company._id.toString()} });
  } catch (error: any) {
    if (error.name === 'CastError') {
        return NextResponse.json({ success: false, error: 'Invalid company ID format' }, { status: 400 });
    }
    return NextResponse.json({ success: false, error: error.message }, { status: 500 });
  }
}

export async function PUT(req: NextRequest, { params }: { params: { id: string } }) {
  await dbConnect();
  try {
    const body = await req.json();
    const validation = companyUpdateSchema.safeParse(body);

    if (!validation.success) {
      return NextResponse.json({ success: false, error: "Validation failed", issues: validation.error.issues }, { status: 400 });
    }

    const updateData: Partial<ICompany> = { ...validation.data };
    if (validation.data.foundedDate) {
      updateData.foundedDate = new Date(validation.data.foundedDate);
    }
     // Handle case where address might be explicitly set to null or undefined to remove it
    if (body.hasOwnProperty('address') && !body.address) {
        updateData.address = undefined;
    }


    const updatedCompany = await Company.findByIdAndUpdate(params.id, updateData, {
      new: true,
      runValidators: true,
    }).lean();

    if (!updatedCompany) {
      return NextResponse.json({ success: false, error: 'Company not found' }, { status: 404 });
    }
    return NextResponse.json({ success: true, data: {...updatedCompany, id: updatedCompany._id.toString()} });
  } catch (error: any) {
    if (error.name === 'CastError') {
        return NextResponse.json({ success: false, error: 'Invalid company ID format' }, { status: 400 });
    }
    if (error.code === 11000) { // Duplicate key error
        const field = Object.keys(error.keyPattern)[0];
        return NextResponse.json({ success: false, error: `Company with this ${field} already exists.` }, { status: 409 });
    }
    return NextResponse.json({ success: false, error: error.message }, { status: 400 });
  }
}

export async function DELETE(req: NextRequest, { params }: { params: { id: string } }) {
  await dbConnect();
  try {
    // Optional: Check if any person is associated with this company
    const associatedPeopleCount = await Person.countDocuments({ companyId: params.id });
    if (associatedPeopleCount > 0) {
      return NextResponse.json({ 
        success: false, 
        error: `Cannot delete company. ${associatedPeopleCount} people are associated with it. Please reassign or delete them first.` 
      }, { status: 409 }); // Conflict
    }

    const deletedCompany = await Company.findByIdAndDelete(params.id);
    if (!deletedCompany) {
      return NextResponse.json({ success: false, error: 'Company not found' }, { status: 404 });
    }
    return NextResponse.json({ success: true, data: { id: params.id, message: 'Company deleted' } });
  } catch (error: any) {
    if (error.name === 'CastError') {
        return NextResponse.json({ success: false, error: 'Invalid company ID format' }, { status: 400 });
    }
    return NextResponse.json({ success: false, error: error.message }, { status: 500 });
  }
}
EOF_SRC_API_COMPANIES_ID_ROUTE_TS
echo "Created src/app/api/companies/[id]/route.ts"

# src/app/api/people/route.ts
cat << 'EOF_SRC_API_PEOPLE_ROUTE_TS' > src/app/api/people/route.ts
import { NextRequest, NextResponse } from 'next/server';
import dbConnect from '@/lib/mongodb';
import Person, { IPerson } from '@/models/Person';
import Company from '@/models/Company'; // Import Company to ensure it's registered for population
import { z } from 'zod';

// Zod schema for Person creation
const personSchema = z.object({
  name: z.string().min(1, "Name is required"),
  email: z.string().email("Invalid email format"),
  birthDate: z.string().optional().refine(val => !val || !isNaN(Date.parse(val)), {
    message: "Invalid date format for birthDate",
  }),
  address: z.object({
    street: z.string().min(1, "Street is required"),
    city: z.string().min(1, "City is required"),
    state: z.string().min(1, "State is required"),
    postalCode: z.string().min(1, "Postal code is required"),
    country: z.string().min(1, "Country is required"),
  }).optional(),
  phoneNumbers: z.array(z.string()).optional(),
  companyId: z.string().optional().nullable(), // Allow null or ObjectId string
});


export async function GET(req: NextRequest) {
  await dbConnect();
  // Ensure Company model is initialized if populate is used
  // A simple way to do this is to perform a trivial operation.
  await Company.findOne({_id: null}).catch(() => {}); // No-op to ensure model is loaded


  try {
    const { searchParams } = new URL(req.url);
    const page = parseInt(searchParams.get('page') || '1', 10);
    const limit = parseInt(searchParams.get('limit') || '10', 10);
    const skip = (page - 1) * limit;

    const peopleQuery = Person.find({})
      .populate('companyId', 'name id') // Populate company name and its string id
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit);
    
    // Using .lean() makes the query faster and returns plain JavaScript objects.
    // However, Mongoose virtuals defined with getters/setters on the schema might not work as expected with .lean()
    // if they depend on `this` being a Mongoose document instance.
    // For simple population and direct field access, .lean() is fine.
    // If you have complex virtuals, you might omit .lean() or ensure they work with plain objects.
    const people = await peopleQuery.lean();


    const totalPeople = await Person.countDocuments();
    
    const formattedPeople = people.map(p => ({
        ...p,
        id: p._id.toString(),
        companyId: p.companyId ? (typeof p.companyId === 'string' ? p.companyId : (p.companyId as any)._id?.toString()) : undefined,
        company: p.companyId && (p.companyId as any).name ? { id: (p.companyId as any)._id?.toString(), name: (p.companyId as any).name } : undefined
    }));

    return NextResponse.json({ 
      success: true, 
      data: formattedPeople,
      pagination: {
        currentPage: page,
        totalPages: Math.ceil(totalPeople / limit),
        totalItems: totalPeople,
        itemsPerPage: limit
      }
    });
  } catch (error: any) {
    console.error("Error fetching people:", error);
    return NextResponse.json({ success: false, error: error.message }, { status: 500 });
  }
}

export async function POST(req: NextRequest) {
  await dbConnect();
  try {
    const body = await req.json();
    const validation = personSchema.safeParse(body);

    if (!validation.success) {
      return NextResponse.json({ success: false, error: "Validation failed", issues: validation.error.issues }, { status: 400 });
    }
    
    const personData: Partial<IPerson> = { ...validation.data };
    if (validation.data.birthDate) {
      personData.birthDate = new Date(validation.data.birthDate);
    }
    if (validation.data.companyId === "" || validation.data.companyId === null) {
      personData.companyId = undefined; // Store as undefined if empty string or null
    } else if (validation.data.companyId) {
      personData.companyId = validation.data.companyId as any; // Mongoose will cast string to ObjectId
    }


    const newPerson = await Person.create(personData);
    // Repopulate after creation if needed, or structure the response carefully
    const populatedPerson = await Person.findById(newPerson._id).populate('companyId', 'name id').lean();

    return NextResponse.json({ 
        success: true, 
        data: {
            ...populatedPerson,
            id: populatedPerson!._id.toString(),
            companyId: populatedPerson!.companyId ? (populatedPerson!.companyId as any)._id?.toString() : undefined,
            company: populatedPerson!.companyId && (populatedPerson!.companyId as any).name ? { id: (populatedPerson!.companyId as any)._id?.toString(), name: (populatedPerson!.companyId as any).name } : undefined
        }
    }, { status: 201 });

  } catch (error: any) {
    if (error.code === 11000) { // Duplicate key error
        const field = Object.keys(error.keyPattern)[0];
        return NextResponse.json({ success: false, error: `Person with this ${field} already exists.` }, { status: 409 });
    }
    console.error("Error creating person:", error);
    return NextResponse.json({ success: false, error: error.message }, { status: 400 });
  }
}
EOF_SRC_API_PEOPLE_ROUTE_TS
echo "Created src/app/api/people/route.ts"

# src/app/api/people/[id]/route.ts
cat << 'EOF_SRC_API_PEOPLE_ID_ROUTE_TS' > src/app/api/people/[id]/route.ts
import { NextRequest, NextResponse } from 'next/server';
import dbConnect from '@/lib/mongodb';
import Person, { IPerson } from '@/models/Person';
import Company from '@/models/Company'; // For population
import { z } from 'zod';

// Zod schema for Person update (all fields optional)
const personUpdateSchema = z.object({
  name: z.string().min(1, "Name is required").optional(),
  email: z.string().email("Invalid email format").optional(),
  birthDate: z.string().optional().refine(val => !val || !isNaN(Date.parse(val)), {
    message: "Invalid date format for birthDate",
  }),
  address: z.object({
    street: z.string().min(1, "Street is required"),
    city: z.string().min(1, "City is required"),
    state: z.string().min(1, "State is required"),
    postalCode: z.string().min(1, "Postal code is required"),
    country: z.string().min(1, "Country is required"),
  }).optional().nullable(),
  phoneNumbers: z.array(z.string()).optional(),
  companyId: z.string().optional().nullable(), // Allow null, empty string (for unsetting), or ObjectId string
}).partial(); // Makes all fields optional

export async function GET(req: NextRequest, { params }: { params: { id: string } }) {
  await dbConnect();
  await Company.findOne({_id: null}).catch(() => {}); // Ensure Company model is initialized for population

  try {
    const person = await Person.findById(params.id).populate('companyId', 'name id').lean();
    if (!person) {
      return NextResponse.json({ success: false, error: 'Person not found' }, { status: 404 });
    }
    const formattedPerson = {
        ...person,
        id: person._id.toString(),
        companyId: person.companyId ? (typeof person.companyId === 'string' ? person.companyId : (person.companyId as any)._id?.toString()) : undefined,
        company: person.companyId && (person.companyId as any).name ? { id: (person.companyId as any)._id?.toString(), name: (person.companyId as any).name } : undefined
    };
    return NextResponse.json({ success: true, data: formattedPerson });
  } catch (error: any) {
     if (error.name === 'CastError') {
        return NextResponse.json({ success: false, error: 'Invalid person ID format' }, { status: 400 });
    }
    console.error("Error fetching person by ID:", error);
    return NextResponse.json({ success: false, error: error.message }, { status: 500 });
  }
}

export async function PUT(req: NextRequest, { params }: { params: { id: string } }) {
  await dbConnect();
  try {
    const body = await req.json();
    const validation = personUpdateSchema.safeParse(body);

    if (!validation.success) {
      return NextResponse.json({ success: false, error: "Validation failed", issues: validation.error.issues }, { status: 400 });
    }
    
    const updateData: Partial<IPerson> = { ...validation.data };
    if (validation.data.birthDate) {
      updateData.birthDate = new Date(validation.data.birthDate);
    }
    // Handle companyId: if empty string or null, set to undefined to remove association
    if (validation.data.companyId === "" || validation.data.companyId === null) {
      updateData.companyId = undefined;
    } else if (validation.data.companyId) {
      updateData.companyId = validation.data.companyId as any; // Mongoose will cast
    }

    // Handle case where address might be explicitly set to null or undefined to remove it
    if (body.hasOwnProperty('address') && !body.address) {
        updateData.address = undefined;
    }


    const updatedPersonDoc = await Person.findByIdAndUpdate(params.id, { $set: updateData } , {
      new: true,
      runValidators: true,
    }).populate('companyId', 'name id'); // Populate after update

    if (!updatedPersonDoc) {
      return NextResponse.json({ success: false, error: 'Person not found' }, { status: 404 });
    }

    const populatedPerson = updatedPersonDoc.toObject(); // Convert to plain object to attach id string

    return NextResponse.json({ 
        success: true, 
        data: {
            ...populatedPerson,
            id: populatedPerson._id.toString(),
            companyId: populatedPerson.companyId ? (populatedPerson.companyId as any)._id?.toString() : undefined,
            company: populatedPerson.companyId && (populatedPerson.companyId as any).name ? { id: (populatedPerson.companyId as any)._id?.toString(), name: (populatedPerson.companyId as any).name } : undefined
        }
    });
  } catch (error: any)
   {
    if (error.name === 'CastError') {
        return NextResponse.json({ success: false, error: 'Invalid person ID format or company ID format' }, { status: 400 });
    }
     if (error.code === 11000) { // Duplicate key error
        const field = Object.keys(error.keyPattern)[0];
        return NextResponse.json({ success: false, error: `Person with this ${field} already exists.` }, { status: 409 });
    }
    console.error("Error updating person:", error);
    return NextResponse.json({ success: false, error: error.message }, { status: 400 });
  }
}

export async function DELETE(req: NextRequest, { params }: { params: { id: string } }) {
  await dbConnect();
  try {
    const deletedPerson = await Person.findByIdAndDelete(params.id);
    if (!deletedPerson) {
      return NextResponse.json({ success: false, error: 'Person not found' }, { status: 404 });
    }
    return NextResponse.json({ success: true, data: { id: params.id, message: 'Person deleted' } });
  } catch (error: any) {
    if (error.name === 'CastError') {
        return NextResponse.json({ success: false, error: 'Invalid person ID format' }, { status: 400 });
    }
    console.error("Error deleting person:", error);
    return NextResponse.json({ success: false, error: error.message }, { status: 500 });
  }
}
EOF_SRC_API_PEOPLE_ID_ROUTE_TS
echo "Created src/app/api/people/[id]/route.ts"


# --- Frontend Page Components (People) ---
# src/app/people/page.tsx
cat << 'EOF_SRC_APP_PEOPLE_PAGE_TSX' > src/app/people/page.tsx
'use client';

import { useState, useEffect, useCallback } from 'react';
import Link from 'next/link';
import PeopleTable from '@/components/PeopleTable';
import { Button } from '@/components/ui/button';
import { Person, PaginatedResponse } from '@/types';
import { PlusCircleIcon } from '@heroicons/react/24/outline';

const API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL || '/api';

export default function PeoplePage() {
  const [people, setPeople] = useState<Person[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [pagination, setPagination] = useState({ currentPage: 1, totalPages: 1, totalItems: 0, itemsPerPage: 10});
  const [searchTerm, setSearchTerm] = useState(''); // Basic search example

  const fetchPeople = useCallback(async (page = 1, limit = 10, search = '') => {
    setIsLoading(true);
    setError(null);
    try {
      // TODO: Implement search on backend if needed, this is just a placeholder for client-side or future backend search
      const response = await fetch(\`\${API_BASE_URL}/people?page=\${page}&limit=\${limit}\${search ? '&q='+search : ''}\`);
      if (!response.ok) {
        const errData = await response.json();
        throw new Error(errData.error || \`Failed to fetch people: \${response.statusText}\`);
      }
      const result: PaginatedResponse<Person> = await response.json();
      if (result.success) {
        setPeople(result.data);
        setPagination(result.pagination);
      } else {
        throw new Error(result.error || 'Unknown error fetching people');
      }
    } catch (err: any) {
      setError(err.message);
      setPeople([]);
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchPeople(pagination.currentPage, pagination.itemsPerPage, searchTerm);
  }, [fetchPeople, pagination.currentPage, pagination.itemsPerPage, searchTerm]);

  const handleDeletePerson = async (id: string) => {
    if (!confirm('Are you sure you want to delete this person? This action cannot be undone.')) return;
    try {
      const response = await fetch(\`\${API_BASE_URL}/people/\${id}\`, { method: 'DELETE' });
      if (!response.ok) {
        const errData = await response.json();
        throw new Error(errData.error || 'Failed to delete person');
      }
      alert('Person deleted successfully');
      // Re-fetch current page or if last item on page, go to previous page
      if (people.length === 1 && pagination.currentPage > 1) {
        handlePageChange(pagination.currentPage - 1);
      } else {
        fetchPeople(pagination.currentPage, pagination.itemsPerPage, searchTerm);
      }
    } catch (err: any) {
      setError(err.message);
      alert(\`Error: \${err.message}\`);
    }
  };
  
  const handlePageChange = (newPage: number) => {
    if (newPage >= 1 && newPage <= pagination.totalPages && newPage !== pagination.currentPage) {
      setPagination(prev => ({ ...prev, currentPage: newPage }));
    }
  };

  return (
    <div className="space-y-6 p-4 md:p-6 bg-white shadow-xl rounded-lg">
      <div className="flex flex-col sm:flex-row justify-between items-center gap-4">
        <h1 className="text-3xl font-bold text-gray-800">Manage People</h1>
        <Link href="/people/new" passHref>
          <Button className="w-full sm:w-auto">
            <PlusCircleIcon className="h-5 w-5 mr-2" />
            Add New Person
          </Button>
        </Link>
      </div>

      {/* Basic Search Input - TODO: Debounce and implement backend search for real app */}
      {/* <div className="my-4">
        <Input 
          type="text"
          placeholder="Search people..."
          value={searchTerm}
          onChange={(e) => setSearchTerm(e.target.value)}
          className="max-w-sm"
        />
      </div> */}

      {isLoading && <div className="flex justify-center items-center p-10"><div className="loader ease-linear rounded-full border-4 border-t-4 border-gray-200 h-12 w-12 mb-4"></div><p className="text-gray-600">Loading people...</p></div>}
      {error && <div role="alert" className="p-4 mb-4 text-sm text-red-700 bg-red-100 rounded-lg"><span className="font-medium">Error:</span> {error}</div>}
      
      {!isLoading && !error && (
        <>
          <PeopleTable people={people} onDelete={handleDeletePerson} />
          {pagination.totalItems > 0 && pagination.totalPages > 1 && (
            <div className="mt-6 flex flex-col sm:flex-row justify-between items-center text-sm text-gray-600">
              <p>Showing {((pagination.currentPage - 1) * pagination.itemsPerPage) + 1} - {Math.min(pagination.currentPage * pagination.itemsPerPage, pagination.totalItems)} of {pagination.totalItems} people</p>
              <div className="flex items-center space-x-2 mt-2 sm:mt-0">
                <Button 
                  onClick={() => handlePageChange(1)} 
                  disabled={pagination.currentPage === 1}
                  variant="outline"
                  size="sm"
                >
                  First
                </Button>
                <Button 
                  onClick={() => handlePageChange(pagination.currentPage - 1)} 
                  disabled={pagination.currentPage === 1}
                  variant="outline"
                  size="sm"
                >
                  Previous
                </Button>
                <span className="px-2">Page {pagination.currentPage} of {pagination.totalPages}</span>
                <Button 
                  onClick={() => handlePageChange(pagination.currentPage + 1)} 
                  disabled={pagination.currentPage === pagination.totalPages}
                  variant="outline"
                  size="sm"
                >
                  Next
                </Button>
                 <Button 
                  onClick={() => handlePageChange(pagination.totalPages)} 
                  disabled={pagination.currentPage === pagination.totalPages}
                  variant="outline"
                  size="sm"
                >
                  Last
                </Button>
              </div>
            </div>
          )}
           {!isLoading && !error && people.length === 0 && (
             <p className="text-center text-gray-500 py-8">No people found. Try adding some!</p>
           )}
        </>
      )}
    </div>
  );
}
EOF_SRC_APP_PEOPLE_PAGE_TSX
echo "Created src/app/people/page.tsx"

# src/app/people/new/page.tsx
cat << 'EOF_SRC_APP_PEOPLE_NEW_PAGE_TSX' > src/app/people/new/page.tsx
'use client';
import PersonForm from '@/components/PersonForm';
import { PersonFormData } from '@/components/PersonForm'; // Assuming PersonForm exports this type
import { useRouter } from 'next/navigation';
import { useState } from 'react';
import { ArrowLeftIcon } from '@heroicons/react/24/outline';
import Link from 'next/link';

const API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL || '/api';

export default function NewPersonPage() {
  const router = useRouter();
  const [error, setError] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleSubmit = async (data: PersonFormData) => {
    setIsSubmitting(true);
    setError(null);
    try {
      // Ensure companyId is null if empty, or string if selected
      const payload = {
        ...data,
        companyId: data.companyId === '' ? null : data.companyId,
        // Convert empty strings in address to undefined if address itself is provided
        address: data.address && Object.values(data.address).some(v => v) ? data.address : undefined,
        phoneNumbers: data.phoneNumbers?.filter(p => p.trim() !== '') || [],
      };

      const response = await fetch(\`\${API_BASE_URL}/people\`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });
      
      const result = await response.json();

      if (!response.ok) {
        throw new Error(result.error || 'Failed to create person. ' + (result.issues ? JSON.stringify(result.issues) : ''));
      }
      
      alert('Person created successfully!');
      router.push('/people');
    } catch (err: any) {
      setError(err.message);
      alert(\`Error: \${err.message}\`);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="max-w-2xl mx-auto p-4 md:p-6 bg-white shadow-xl rounded-lg">
      <Link href="/people" className="inline-flex items-center text-blue-600 hover:text-blue-800 mb-6">
        <ArrowLeftIcon className="h-5 w-5 mr-2" />
        Back to People List
      </Link>
      <h1 className="text-3xl font-bold text-gray-800 mb-6">Add New Person</h1>
      {error && <div role="alert" className="p-4 mb-4 text-sm text-red-700 bg-red-100 rounded-lg"><span className="font-medium">Error:</span> {error}</div>}
      <PersonForm onSubmit={handleSubmit} isSubmitting={isSubmitting} />
    </div>
  );
}
EOF_SRC_APP_PEOPLE_NEW_PAGE_TSX
echo "Created src/app/people/new/page.tsx"

# src/app/people/[id]/edit/page.tsx
cat << 'EOF_SRC_APP_PEOPLE_ID_EDIT_PAGE_TSX' > src/app/people/[id]/edit/page.tsx
'use client';
import PersonForm from '@/components/PersonForm';
import { PersonFormData } from '@/components/PersonForm';
import { Person } from '@/types';
import { useRouter, useParams } from 'next/navigation';
import { useState, useEffect, useCallback } from 'react';
import { ArrowLeftIcon } from '@heroicons/react/24/outline';
import Link from 'next/link';

const API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL || '/api';

export default function EditPersonPage() {
  const router = useRouter();
  const params = useParams();
  const id = params.id as string;

  const [person, setPerson] = useState<Person | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const fetchPerson = useCallback(async () => {
    if (!id) return;
    setIsLoading(true);
    setError(null);
    try {
      const response = await fetch(\`\${API_BASE_URL}/people/\${id}\`);
      if (!response.ok) {
        const errData = await response.json();
        throw new Error(errData.error || 'Failed to fetch person details');
      }
      const result = await response.json();
      if (result.success) {
        // Transform data for the form, e.g., date format if necessary
        const fetchedPerson = result.data;
        if (fetchedPerson.birthDate) {
          fetchedPerson.birthDate = new Date(fetchedPerson.birthDate).toISOString().split('T')[0];
        }
        setPerson(fetchedPerson);
      } else {
        throw new Error(result.error || 'Error in API response');
      }
    } catch (err: any) {
      setError(err.message);
      setPerson(null);
    } finally {
      setIsLoading(false);
    }
  }, [id]);

  useEffect(() => {
    fetchPerson();
  }, [fetchPerson]);

  const handleSubmit = async (data: PersonFormData) => {
    if (!id) return;
    setIsSubmitting(true);
    setError(null);
    try {
      const payload = {
        ...data,
        companyId: data.companyId === '' ? null : data.companyId,
        address: data.address && Object.values(data.address).some(v => v) ? data.address : undefined,
        phoneNumbers: data.phoneNumbers?.filter(p => p.trim() !== '') || [],
      };

      const response = await fetch(\`\${API_BASE_URL}/people/\${id}\`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });
      const result = await response.json();
      if (!response.ok) {
        throw new Error(result.error || 'Failed to update person. ' + (result.issues ? JSON.stringify(result.issues) : ''));
      }
      alert('Person updated successfully!');
      router.push('/people');
    } catch (err: any) {
      setError(err.message);
      alert(\`Error: \${err.message}\`);
    } finally {
      setIsSubmitting(false);
    }
  };

  if (isLoading) return <div className="flex justify-center items-center p-10"><div className="loader ease-linear rounded-full border-4 border-t-4 border-gray-200 h-12 w-12 mb-4"></div><p className="text-gray-600">Loading person details...</p></div>;
  if (error && !person) return <div role="alert" className="p-4 m-4 text-sm text-red-700 bg-red-100 rounded-lg"><span className="font-medium">Error:</span> {error}. <Link href="/people" className="font-semibold underline hover:text-red-800">Go back to list.</Link></div>;
  if (!person) return <p className="text-center text-gray-500 py-8">Person not found.</p>;

  return (
    <div className="max-w-2xl mx-auto p-4 md:p-6 bg-white shadow-xl rounded-lg">
      <Link href="/people" className="inline-flex items-center text-blue-600 hover:text-blue-800 mb-6">
        <ArrowLeftIcon className="h-5 w-5 mr-2" />
        Back to People List
      </Link>
      <h1 className="text-3xl font-bold text-gray-800 mb-6">Edit Person: {person.name}</h1>
      {error && <div role="alert" className="p-4 mb-4 text-sm text-red-700 bg-red-100 rounded-lg"><span className="font-medium">Error during submission:</span> {error}</div>}
      <PersonForm onSubmit={handleSubmit} initialData={person} isSubmitting={isSubmitting} />
    </div>
  );
}
EOF_SRC_APP_PEOPLE_ID_EDIT_PAGE_TSX
echo "Created src/app/people/[id]/edit/page.tsx"


# --- Frontend Page Components (Companies) ---
# src/app/companies/page.tsx
cat << 'EOF_SRC_APP_COMPANIES_PAGE_TSX' > src/app/companies/page.tsx
'use client';

import { useState, useEffect, useCallback } from 'react';
import Link from 'next/link';
import CompaniesTable from '@/components/CompaniesTable';
import { Button } from '@/components/ui/button';
import { Company, PaginatedResponse } from '@/types';
import { PlusCircleIcon } from '@heroicons/react/24/outline';

const API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL || '/api';

export default function CompaniesPage() {
  const [companies, setCompanies] = useState<Company[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [pagination, setPagination] = useState({ currentPage: 1, totalPages: 1, totalItems: 0, itemsPerPage: 10});

  const fetchCompanies = useCallback(async (page = 1, limit = 10) => {
    setIsLoading(true);
    setError(null);
    try {
      const response = await fetch(\`\${API_BASE_URL}/companies?page=\${page}&limit=\${limit}\`);
      if (!response.ok) {
        const errData = await response.json();
        throw new Error(errData.error || \`Failed to fetch companies: \${response.statusText}\`);
      }
      const result: PaginatedResponse<Company> = await response.json();
      if (result.success) {
        setCompanies(result.data);
        setPagination(result.pagination);
      } else {
        throw new Error(result.error || 'Unknown error fetching companies');
      }
    } catch (err: any) {
      setError(err.message);
      setCompanies([]);
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchCompanies(pagination.currentPage, pagination.itemsPerPage);
  }, [fetchCompanies, pagination.currentPage, pagination.itemsPerPage]);

  const handleDeleteCompany = async (id: string) => {
    if (!confirm('Are you sure you want to delete this company? This may affect associated people if not handled on the backend.')) return;
    try {
      const response = await fetch(\`\${API_BASE_URL}/companies/\${id}\`, { method: 'DELETE' });
      const result = await response.json();
      if (!response.ok) {
        throw new Error(result.error || 'Failed to delete company');
      }
      alert('Company deleted successfully');
      if (companies.length === 1 && pagination.currentPage > 1) {
        handlePageChange(pagination.currentPage - 1);
      } else {
        fetchCompanies(pagination.currentPage, pagination.itemsPerPage);
      }
    } catch (err: any) {
      setError(err.message);
      alert(\`Error: \${err.message}\`);
    }
  };
  
  const handlePageChange = (newPage: number) => {
    if (newPage >= 1 && newPage <= pagination.totalPages && newPage !== pagination.currentPage) {
      setPagination(prev => ({ ...prev, currentPage: newPage }));
    }
  };

  return (
    <div className="space-y-6 p-4 md:p-6 bg-white shadow-xl rounded-lg">
      <div className="flex flex-col sm:flex-row justify-between items-center gap-4">
        <h1 className="text-3xl font-bold text-gray-800">Manage Companies</h1>
        <Link href="/companies/new" passHref>
          <Button className="w-full sm:w-auto">
             <PlusCircleIcon className="h-5 w-5 mr-2" />
            Add New Company
          </Button>
        </Link>
      </div>

      {isLoading && <div className="flex justify-center items-center p-10"><div className="loader ease-linear rounded-full border-4 border-t-4 border-gray-200 h-12 w-12 mb-4"></div><p className="text-gray-600">Loading companies...</p></div>}
      {error && <div role="alert" className="p-4 mb-4 text-sm text-red-700 bg-red-100 rounded-lg"><span className="font-medium">Error:</span> {error}</div>}
      
      {!isLoading && !error && (
        <>
          <CompaniesTable companies={companies} onDelete={handleDeleteCompany} />
           {pagination.totalItems > 0 && pagination.totalPages > 1 && (
            <div className="mt-6 flex flex-col sm:flex-row justify-between items-center text-sm text-gray-600">
              <p>Showing {((pagination.currentPage - 1) * pagination.itemsPerPage) + 1} - {Math.min(pagination.currentPage * pagination.itemsPerPage, pagination.totalItems)} of {pagination.totalItems} companies</p>
              <div className="flex items-center space-x-2 mt-2 sm:mt-0">
                <Button 
                  onClick={() => handlePageChange(1)} 
                  disabled={pagination.currentPage === 1}
                  variant="outline"
                  size="sm"
                >
                  First
                </Button>
                <Button 
                  onClick={() => handlePageChange(pagination.currentPage - 1)} 
                  disabled={pagination.currentPage === 1}
                  variant="outline"
                  size="sm"
                >
                  Previous
                </Button>
                <span className="px-2">Page {pagination.currentPage} of {pagination.totalPages}</span>
                <Button 
                  onClick={() => handlePageChange(pagination.currentPage + 1)} 
                  disabled={pagination.currentPage === pagination.totalPages}
                  variant="outline"
                  size="sm"
                >
                  Next
                </Button>
                 <Button 
                  onClick={() => handlePageChange(pagination.totalPages)} 
                  disabled={pagination.currentPage === pagination.totalPages}
                  variant="outline"
                  size="sm"
                >
                  Last
                </Button>
              </div>
            </div>
          )}
          {!isLoading && !error && companies.length === 0 && (
             <p className="text-center text-gray-500 py-8">No companies found. Try adding some!</p>
           )}
        </>
      )}
    </div>
  );
}
EOF_SRC_APP_COMPANIES_PAGE_TSX
echo "Created src/app/companies/page.tsx"

# src/app/companies/new/page.tsx
cat << 'EOF_SRC_APP_COMPANIES_NEW_PAGE_TSX' > src/app/companies/new/page.tsx
'use client';
import CompanyForm from '@/components/CompanyForm';
import { CompanyFormData } from '@/components/CompanyForm';
import { useRouter } from 'next/navigation';
import { useState } from 'react';
import { ArrowLeftIcon } from '@heroicons/react/24/outline';
import Link from 'next/link';

const API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL || '/api';

export default function NewCompanyPage() {
  const router = useRouter();
  const [error, setError] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleSubmit = async (data: CompanyFormData) => {
    setIsSubmitting(true);
    setError(null);
    try {
      // Convert empty strings in address to undefined if address itself is provided
      const payload = {
        ...data,
        address: data.address && Object.values(data.address).some(v => v) ? data.address : undefined,
      };

      const response = await fetch(\`\${API_BASE_URL}/companies\`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });
      const result = await response.json();
      if (!response.ok) {
        throw new Error(result.error || 'Failed to create company. ' + (result.issues ? JSON.stringify(result.issues) : ''));
      }
      alert('Company created successfully!');
      router.push('/companies');
    } catch (err: any) {
      setError(err.message);
      alert(\`Error: \${err.message}\`);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="max-w-2xl mx-auto p-4 md:p-6 bg-white shadow-xl rounded-lg">
      <Link href="/companies" className="inline-flex items-center text-blue-600 hover:text-blue-800 mb-6">
        <ArrowLeftIcon className="h-5 w-5 mr-2" />
        Back to Companies List
      </Link>
      <h1 className="text-3xl font-bold text-gray-800 mb-6">Add New Company</h1>
      {error && <div role="alert" className="p-4 mb-4 text-sm text-red-700 bg-red-100 rounded-lg"><span className="font-medium">Error:</span> {error}</div>}
      <CompanyForm onSubmit={handleSubmit} isSubmitting={isSubmitting} />
    </div>
  );
}
EOF_SRC_APP_COMPANIES_NEW_PAGE_TSX
echo "Created src/app/companies/new/page.tsx"

# src/app/companies/[id]/edit/page.tsx
cat << 'EOF_SRC_APP_COMPANIES_ID_EDIT_PAGE_TSX' > src/app/companies/[id]/edit/page.tsx
'use client';
import CompanyForm from '@/components/CompanyForm';
import { CompanyFormData } from '@/components/CompanyForm';
import { Company } from '@/types';
import { useRouter, useParams } from 'next/navigation';
import { useState, useEffect, useCallback } from 'react';
import { ArrowLeftIcon } from '@heroicons/react/24/outline';
import Link from 'next/link';

const API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL || '/api';

export default function EditCompanyPage() {
  const router = useRouter();
  const params = useParams();
  const id = params.id as string;

  const [company, setCompany] = useState<Company | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const fetchCompany = useCallback(async () => {
    if (!id) return;
    setIsLoading(true);
    setError(null);
    try {
      const response = await fetch(\`\${API_BASE_URL}/companies/\${id}\`);
      if (!response.ok) {
         const errData = await response.json();
        throw new Error(errData.error || 'Failed to fetch company details');
      }
      const result = await response.json();
      if (result.success) {
        const fetchedCompany = result.data;
        // Format date for input type="date"
        if (fetchedCompany.foundedDate) {
          fetchedCompany.foundedDate = new Date(fetchedCompany.foundedDate).toISOString().split('T')[0];
        }
        setCompany(fetchedCompany);
      } else {
        throw new Error(result.error || 'Error in API response');
      }
    } catch (err: any) {
      setError(err.message);
      setCompany(null);
    } finally {
      setIsLoading(false);
    }
  }, [id]);

  useEffect(() => {
    fetchCompany();
  }, [fetchCompany]);

  const handleSubmit = async (data: CompanyFormData) => {
    if (!id) return;
    setIsSubmitting(true);
    setError(null);
    try {
      const payload = {
        ...data,
        address: data.address && Object.values(data.address).some(v => v) ? data.address : undefined,
      };

      const response = await fetch(\`\${API_BASE_URL}/companies/\${id}\`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });
      const result = await response.json();
      if (!response.ok) {
        throw new Error(result.error || 'Failed to update company. ' + (result.issues ? JSON.stringify(result.issues) : ''));
      }
      alert('Company updated successfully!');
      router.push('/companies');
    } catch (err: any) {
      setError(err.message);
      alert(\`Error: \${err.message}\`);
    } finally {
      setIsSubmitting(false);
    }
  };

  if (isLoading) return <div className="flex justify-center items-center p-10"><div className="loader ease-linear rounded-full border-4 border-t-4 border-gray-200 h-12 w-12 mb-4"></div><p className="text-gray-600">Loading company details...</p></div>;
  if (error && !company) return <div role="alert" className="p-4 m-4 text-sm text-red-700 bg-red-100 rounded-lg"><span className="font-medium">Error:</span> {error}. <Link href="/companies" className="font-semibold underline hover:text-red-800">Go back to list.</Link></div>;
  if (!company) return <p className="text-center text-gray-500 py-8">Company not found.</p>;

  return (
    <div className="max-w-2xl mx-auto p-4 md:p-6 bg-white shadow-xl rounded-lg">
      <Link href="/companies" className="inline-flex items-center text-blue-600 hover:text-blue-800 mb-6">
        <ArrowLeftIcon className="h-5 w-5 mr-2" />
        Back to Companies List
      </Link>
      <h1 className="text-3xl font-bold text-gray-800 mb-6">Edit Company: {company.name}</h1>
       {error && <div role="alert" className="p-4 mb-4 text-sm text-red-700 bg-red-100 rounded-lg"><span className="font-medium">Error during submission:</span> {error}</div>}
      <CompanyForm onSubmit={handleSubmit} initialData={company} isSubmitting={isSubmitting} />
    </div>
  );
}
EOF_SRC_APP_COMPANIES_ID_EDIT_PAGE_TSX
echo "Created src/app/companies/[id]/edit/page.tsx"


# --- UI Components ---
# src/components/ui/button.tsx
cat << 'EOF_SRC_COMPONENTS_UI_BUTTON_TSX' > src/components/ui/button.tsx
import React from 'react';
import { Slot } from '@radix-ui/react-slot';
import { cva, type VariantProps } from 'class-variance-authority';
import { cn } from '@/lib/utils'; // Assuming you have a cn utility

const buttonVariants = cva(
  'inline-flex items-center justify-center rounded-md text-sm font-medium ring-offset-background transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50',
  {
    variants: {
      variant: {
        default: 'bg-blue-600 text-primary-foreground hover:bg-blue-600/90 text-white',
        destructive:
          'bg-red-600 text-destructive-foreground hover:bg-red-600/90 text-white',
        outline:
          'border border-input bg-background hover:bg-accent hover:text-accent-foreground',
        secondary:
          'bg-slate-200 text-secondary-foreground hover:bg-slate-200/80',
        ghost: 'hover:bg-accent hover:text-accent-foreground',
        link: 'text-primary underline-offset-4 hover:underline',
      },
      size: {
        default: 'h-10 px-4 py-2',
        sm: 'h-9 rounded-md px-3',
        lg: 'h-11 rounded-md px-8',
        icon: 'h-10 w-10',
      },
    },
    defaultVariants: {
      variant: 'default',
      size: 'default',
    },
  }
);

export interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {
  asChild?: boolean;
}

const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant, size, asChild = false, ...props }, ref) => {
    const Comp = asChild ? Slot : 'button';
    return (
      <Comp
        className={cn(buttonVariants({ variant, size, className }))}
        ref={ref}
        {...props}
      />
    );
  }
);
Button.displayName = 'Button';

export { Button, buttonVariants };
EOF_SRC_COMPONENTS_UI_BUTTON_TSX
echo "Created src/components/ui/button.tsx"

# src/components/ui/input.tsx
cat << 'EOF_SRC_COMPONENTS_UI_INPUT_TSX' > src/components/ui/input.tsx
import * as React from 'react';
import { cn } from '@/lib/utils'; // Assuming you have a cn utility

export interface InputProps
  extends React.InputHTMLAttributes<HTMLInputElement> {}

const Input = React.forwardRef<HTMLInputElement, InputProps>(
  ({ className, type, ...props }, ref) => {
    return (
      <input
        type={type}
        className={cn(
          'flex h-10 w-full rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background file:border-0 file:bg-transparent file:text-sm file:font-medium placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50',
          'border-gray-300 focus:border-blue-500 focus:ring-blue-500', // Custom styling
          className
        )}
        ref={ref}
        {...props}
      />
    );
  }
);
Input.displayName = 'Input';

export { Input };
EOF_SRC_COMPONENTS_UI_INPUT_TSX
echo "Created src/components/ui/input.tsx"

# src/components/ui/label.tsx
cat << 'EOF_SRC_COMPONENTS_UI_LABEL_TSX' > src/components/ui/label.tsx
'use client';
import * as React from 'react';
import * as LabelPrimitive from '@radix-ui/react-label';
import { cva, type VariantProps } from 'class-variance-authority';
import { cn } from '@/lib/utils'; // Assuming you have a cn utility

const labelVariants = cva(
  'text-sm font-medium leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70'
);

const Label = React.forwardRef<
  React.ElementRef<typeof LabelPrimitive.Root>,
  React.ComponentPropsWithoutRef<typeof LabelPrimitive.Root> &
    VariantProps<typeof labelVariants>
>(({ className, ...props }, ref) => (
  <LabelPrimitive.Root
    ref={ref}
    className={cn(labelVariants(), 'block text-gray-700 mb-1', className)} // Custom styling
    {...props}
  />
));
Label.displayName = LabelPrimitive.Root.displayName;

export { Label };
EOF_SRC_COMPONENTS_UI_LABEL_TSX
echo "Created src/components/ui/label.tsx"

# src/components/ui/textarea.tsx
cat << 'EOF_SRC_COMPONENTS_UI_TEXTAREA_TSX' > src/components/ui/textarea.tsx
import * as React from "react"
import { cn } from "@/lib/utils"

export interface TextareaProps
  extends React.TextareaHTMLAttributes<HTMLTextAreaElement> {}

const Textarea = React.forwardRef<HTMLTextAreaElement, TextareaProps>(
  ({ className, ...props }, ref) => {
    return (
      <textarea
        className={cn(
          "flex min-h-[80px] w-full rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50",
          "border-gray-300 focus:border-blue-500 focus:ring-blue-500", // Custom styling
          className
        )}
        ref={ref}
        {...props}
      />
    )
  }
)
Textarea.displayName = "Textarea"

export { Textarea }
EOF_SRC_COMPONENTS_UI_TEXTAREA_TSX
echo "Created src/components/ui/textarea.tsx"

# src/components/ui/modal.tsx (Basic example, can be expanded)
cat << 'EOF_SRC_COMPONENTS_UI_MODAL_TSX' > src/components/ui/modal.tsx
'use client';
import React, { ReactNode } from 'react';

interface ModalProps {
  isOpen: boolean;
  onClose: () => void;
  title?: string;
  children: ReactNode;
}

export default function Modal({ isOpen, onClose, title, children }: ModalProps) {
  if (!isOpen) return null;

  return (
    <div 
      className="fixed inset-0 bg-black bg-opacity-50 z-50 flex justify-center items-center p-4"
      onClick={onClose} // Close on overlay click
    >
      <div 
        className="bg-white p-6 rounded-lg shadow-xl max-w-lg w-full"
        onClick={(e) => e.stopPropagation()} // Prevent close when clicking inside modal content
      >
        {title && <h2 className="text-xl font-semibold mb-4 text-gray-800">{title}</h2>}
        <div>{children}</div>
        <div className="mt-6 flex justify-end">
          <button
            onClick={onClose}
            className="px-4 py-2 bg-gray-200 text-gray-700 rounded-md hover:bg-gray-300 transition"
          >
            Close
          </button>
        </div>
      </div>
    </div>
  );
}
EOF_SRC_COMPONENTS_UI_MODAL_TSX
echo "Created src/components/ui/modal.tsx"

# src/components/Navbar.tsx
cat << 'EOF_SRC_COMPONENTS_NAVBAR_TSX' > src/components/Navbar.tsx
'use client';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { HomeIcon, UserGroupIcon, BuildingOffice2Icon } from '@heroicons/react/24/solid'; // Using solid icons

const navLinks = [
  { href: '/', label: 'Home', icon: HomeIcon },
  { href: '/people', label: 'People', icon: UserGroupIcon },
  { href: '/companies', label: 'Companies', icon: BuildingOffice2Icon },
];

export default function Navbar() {
  const pathname = usePathname();

  return (
    <nav className="bg-gray-800 text-white shadow-lg sticky top-0 z-50">
      <div className="container mx-auto px-4">
        <div className="flex items-center justify-between h-16">
          <Link href="/" className="text-2xl font-bold hover:text-gray-300 transition-colors">
            PeopleApp
          </Link>
          <div className="flex space-x-2 md:space-x-4">
            {navLinks.map(({ href, label, icon: Icon }) => {
              const isActive = pathname === href || (href !== '/' && pathname.startsWith(href));
              return (
                <Link
                  key={label}
                  href={href}
                  className={`flex items-center px-3 py-2 rounded-md text-sm font-medium transition-all
                    ${isActive
                      ? 'bg-gray-900 text-white'
                      : 'text-gray-300 hover:bg-gray-700 hover:text-white'
                    }`}
                >
                  <Icon className="h-5 w-5 mr-0 md:mr-2" />
                  <span className="hidden md:inline">{label}</span>
                </Link>
              );
            })}
          </div>
        </div>
      </div>
    </nav>
  );
}
EOF_SRC_COMPONENTS_NAVBAR_TSX
echo "Created src/components/Navbar.tsx"

# src/components/PeopleTable.tsx
cat << 'EOF_SRC_COMPONENTS_PEOPLE_TABLE_TSX' > src/components/PeopleTable.tsx
'use client';
import Link from 'next/link';
import { Person } from '@/types';
import { Button } from '@/components/ui/button';
import { TrashIcon, PencilSquareIcon } from '@heroicons/react/24/outline'; // Using outline for action icons

interface PeopleTableProps {
  people: Person[];
  onDelete: (id: string) => Promise<void>;
}

export default function PeopleTable({ people, onDelete }: PeopleTableProps) {
  if (!people || people.length === 0) {
    return null; // Handled by parent component's "No people found" message
  }

  return (
    <div className="overflow-x-auto shadow-md rounded-lg border border-gray-200">
      <table className="min-w-full divide-y divide-gray-200 bg-white">
        <thead className="bg-gray-50">
          <tr>
            <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Name</th>
            <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Email</th>
            <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Company</th>
            <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Birth Date</th>
            <th scope="col" className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
          </tr>
        </thead>
        <tbody className="bg-white divide-y divide-gray-200">
          {people.map((person) => (
            <tr key={person.id} className="hover:bg-gray-50 transition-colors">
              <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">{person.name}</td>
              <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{person.email}</td>
              <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                {person.company ? (
                  <Link href={\`/companies/\${person.company.id}/edit\` } className="text-blue-600 hover:underline">
                    {person.company.name}
                  </Link>
                ) : (
                  <span className="text-gray-400">N/A</span>
                )}
              </td>
              <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                {person.birthDate ? new Date(person.birthDate).toLocaleDateString() : <span className="text-gray-400">N/A</span>}
              </td>
              <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium space-x-2">
                <Link href={\`/people/\${person.id}/edit\`} passHref>
                  <Button variant="outline" size="sm" className="text-blue-600 border-blue-500 hover:bg-blue-50">
                    <PencilSquareIcon className="h-4 w-4" />
                    <span className="sr-only">Edit</span>
                  </Button>
                </Link>
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => onDelete(person.id)}
                  className="text-red-600 border-red-500 hover:bg-red-50"
                >
                  <TrashIcon className="h-4 w-4" />
                   <span className="sr-only">Delete</span>
                </Button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
EOF_SRC_COMPONENTS_PEOPLE_TABLE_TSX
echo "Created src/components/PeopleTable.tsx"

# src/components/PersonForm.tsx
cat << 'EOF_SRC_COMPONENTS_PERSON_FORM_TSX' > src/components/PersonForm.tsx
'use client';
import { useForm, SubmitHandler, Controller, useFieldArray } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Button } from '@/components/ui/button';
import { Textarea } from '@/components/ui/textarea'; // Assuming you have this
import { Person, Company, IPersonAddress } from '@/types';
import { useEffect, useState } from 'react';
import { PlusIcon, TrashIcon } from '@heroicons/react/24/outline';

const API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL || '/api';

const addressSchema = z.object({
  street: z.string().min(1, 'Street is required').max(100),
  city: z.string().min(1, 'City is required').max(50),
  state: z.string().min(1, 'State is required').max(50),
  postalCode: z.string().min(1, 'Postal Code is required').max(20),
  country: z.string().min(1, 'Country is required').max(50),
}).partial().refine(data => { // Make address optional if all fields are empty
    return Object.values(data).some(val => val && val.trim() !== '');
}, {
    message: "Address requires at least one field if provided.",
    path: [], // General path for the object
}).or(z.undefined());


const personFormSchema = z.object({
  name: z.string().min(2, 'Name must be at least 2 characters').max(100),
  email: z.string().email('Invalid email address').max(100),
  birthDate: z.string().optional().refine(val => !val || !isNaN(Date.parse(val)), {
    message: "Invalid date format. Use YYYY-MM-DD.",
  }),
  companyId: z.string().optional().nullable(),
  phoneNumbers: z.array(z.string().min(5, "Phone number seems too short").max(20).optional()).optional(),
  address: addressSchema,
});

export type PersonFormData = z.infer<typeof personFormSchema>;

interface PersonFormProps {
  onSubmit: SubmitHandler<PersonFormData>;
  initialData?: Partial<Person>; // Making it partial for flexibility
  isSubmitting?: boolean;
}

export default function PersonForm({ onSubmit, initialData, isSubmitting }: PersonFormProps) {
  const [companies, setCompanies] = useState<Company[]>([]);
  const [showAddress, setShowAddress] = useState(!!initialData?.address);

  const { control, register, handleSubmit, formState: { errors }, reset, watch, setValue } = useForm<PersonFormData>({
    resolver: zodResolver(personFormSchema),
    defaultValues: {
      name: initialData?.name || '',
      email: initialData?.email || '',
      birthDate: initialData?.birthDate ? new Date(initialData.birthDate).toISOString().split('T')[0] : '',
      companyId: initialData?.companyId || null, // Ensure null for 'No Company'
      phoneNumbers: initialData?.phoneNumbers || [''],
      address: initialData?.address || { street: '', city: '', state: '', postalCode: '', country: '' },
    },
  });

  const { fields, append, remove } = useFieldArray({
    control,
    name: "phoneNumbers"
  });

  useEffect(() => {
    // Fetch companies for dropdown
    const fetchCompanies = async () => {
      try {
        const response = await fetch(\`\${API_BASE_URL}/companies?limit=1000\`); // Get all companies
        const result = await response.json();
        if (result.success) {
          setCompanies(result.data);
        }
      } catch (error) {
        console.error("Failed to fetch companies", error);
      }
    };
    fetchCompanies();
  }, []);

  useEffect(() => {
    if (initialData) {
      reset({
        name: initialData.name || '',
        email: initialData.email || '',
        birthDate: initialData.birthDate ? new Date(initialData.birthDate).toISOString().split('T')[0] : '',
        companyId: initialData.companyId || null,
        phoneNumbers: initialData.phoneNumbers?.length ? initialData.phoneNumbers : [''],
        address: initialData.address || { street: '', city: '', state: '', postalCode: '', country: '' },
      });
      setShowAddress(!!initialData.address && Object.values(initialData.address).some(v => v));
    }
  }, [initialData, reset]);
  
  const watchedAddress = watch("address");
  useEffect(() => {
    if (watchedAddress && Object.values(watchedAddress).some(val => val && String(val).trim() !== '')) {
        setShowAddress(true);
    }
  }, [watchedAddress]);


  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
      <div>
        <Label htmlFor="name">Full Name</Label>
        <Input id="name" {...register('name')} aria-invalid={errors.name ? "true" : "false"} />
        {errors.name && <p role="alert" className="text-red-500 text-sm mt-1">{errors.name.message}</p>}
      </div>

      <div>
        <Label htmlFor="email">Email Address</Label>
        <Input id="email" type="email" {...register('email')} aria-invalid={errors.email ? "true" : "false"} />
        {errors.email && <p role="alert" className="text-red-500 text-sm mt-1">{errors.email.message}</p>}
      </div>

      <div>
        <Label htmlFor="birthDate">Birth Date (YYYY-MM-DD)</Label>
        <Input id="birthDate" type="date" {...register('birthDate')} aria-invalid={errors.birthDate ? "true" : "false"} />
        {errors.birthDate && <p role="alert" className="text-red-500 text-sm mt-1">{errors.birthDate.message}</p>}
      </div>

      <div>
        <Label htmlFor="companyId">Company</Label>
        <select
          id="companyId"
          {...register('companyId')}
          className="block w-full h-10 rounded-md border border-gray-300 bg-white px-3 py-2 text-sm shadow-sm focus:border-blue-500 focus:outline-none focus:ring-blue-500 disabled:cursor-not-allowed disabled:opacity-50"
        >
          <option value="">-- No Company --</option>
          {companies.map(company => (
            <option key={company.id} value={company.id}>{company.name}</option>
          ))}
        </select>
        {errors.companyId && <p role="alert" className="text-red-500 text-sm mt-1">{errors.companyId.message}</p>}
      </div>

      <div>
        <Label>Phone Numbers</Label>
        {fields.map((field, index) => (
          <div key={field.id} className="flex items-center space-x-2 mb-2">
            <Input
              {...register(\`phoneNumbers.\${index}\`)}
              placeholder="e.g., +1-555-123-4567"
              className="flex-grow"
            />
            {fields.length > 1 && (
              <Button type="button" variant="ghost" size="sm" onClick={() => remove(index)} aria-label="Remove phone number">
                <TrashIcon className="h-5 w-5 text-red-500" />
              </Button>
            )}
          </div>
        ))}
        {errors.phoneNumbers && <p role="alert" className="text-red-500 text-sm mt-1">{errors.phoneNumbers.message || errors.phoneNumbers.root?.message}</p>}
         {errors.phoneNumbers?.map((err, index) => err && <p key={index} role="alert" className="text-red-500 text-sm mt-1">{err.message}</p>)}

        <Button type="button" variant="outline" size="sm" onClick={() => append('')} className="mt-1">
          <PlusIcon className="h-4 w-4 mr-1" /> Add Phone
        </Button>
      </div>

      <div className="space-y-1">
        {!showAddress ? (
            <Button type="button" variant="outline" onClick={() => setShowAddress(true)}>
                Add Address (Optional)
            </Button>
        ) : (
            <h3 className="text-lg font-medium text-gray-700 pt-2">Address (Optional)</h3>
        )}
      </div>

      {showAddress && (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 p-4 border rounded-md">
            <div>
                <Label htmlFor="address.street">Street</Label>
                <Input id="address.street" {...register('address.street')} />
                {errors.address?.street && <p role="alert" className="text-red-500 text-sm mt-1">{errors.address.street.message}</p>}
            </div>
            <div>
                <Label htmlFor="address.city">City</Label>
                <Input id="address.city" {...register('address.city')} />
                {errors.address?.city && <p role="alert" className="text-red-500 text-sm mt-1">{errors.address.city.message}</p>}
            </div>
            <div>
                <Label htmlFor="address.state">State / Province</Label>
                <Input id="address.state" {...register('address.state')} />
                {errors.address?.state && <p role="alert" className="text-red-500 text-sm mt-1">{errors.address.state.message}</p>}
            </div>
            <div>
                <Label htmlFor="address.postalCode">Postal Code</Label>
                <Input id="address.postalCode" {...register('address.postalCode')} />
                {errors.address?.postalCode && <p role="alert" className="text-red-500 text-sm mt-1">{errors.address.postalCode.message}</p>}
            </div>
            <div className="md:col-span-2">
                <Label htmlFor="address.country">Country</Label>
                <Input id="address.country" {...register('address.country')} />
                {errors.address?.country && <p role="alert" className="text-red-500 text-sm mt-1">{errors.address.country.message}</p>}
            </div>
             {errors.address && !errors.address.street && !errors.address.city && !errors.address.state && !errors.address.postalCode && !errors.address.country && errors.address.message && (
                <p role="alert" className="text-red-500 text-sm mt-1 md:col-span-2">{errors.address.message}</p>
            )}
            <Button type="button" variant="ghost" size="sm" className="md:col-span-2 justify-self-start mt-2" onClick={() => {
                setValue('address', { street: '', city: '', state: '', postalCode: '', country: '' });
                setShowAddress(false);
            }}>
                Clear Address
            </Button>
        </div>
      )}


      <Button type="submit" disabled={isSubmitting} className="w-full sm:w-auto">
        {isSubmitting ? (
            <div className="flex items-center">
                <svg className="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                    <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                    <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                </svg>
                Submitting...
            </div>
        ) : (initialData?.id ? 'Save Changes' : 'Create Person')}
      </Button>
    </form>
  );
}
EOF_SRC_COMPONENTS_PERSON_FORM_TSX
echo "Created src/components/PersonForm.tsx"

# src/components/CompaniesTable.tsx
cat << 'EOF_SRC_COMPONENTS_COMPANIES_TABLE_TSX' > src/components/CompaniesTable.tsx
'use client';
import Link from 'next/link';
import { Company } from '@/types';
import { Button } from '@/components/ui/button';
import { TrashIcon, PencilSquareIcon } from '@heroicons/react/24/outline';

interface CompaniesTableProps {
  companies: Company[];
  onDelete: (id: string) => Promise<void>;
}

export default function CompaniesTable({ companies, onDelete }: CompaniesTableProps) {
   if (!companies || companies.length === 0) {
    return null; // Handled by parent component
  }

  return (
    <div className="overflow-x-auto shadow-md rounded-lg border border-gray-200">
      <table className="min-w-full divide-y divide-gray-200 bg-white">
        <thead className="bg-gray-50">
          <tr>
            <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Name</th>
            <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Contact Email</th>
            <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Industry</th>
            <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Founded</th>
            <th scope="col" className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
          </tr>
        </thead>
        <tbody className="bg-white divide-y divide-gray-200">
          {companies.map((company) => (
            <tr key={company.id} className="hover:bg-gray-50 transition-colors">
              <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">{company.name}</td>
              <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{company.contactEmail}</td>
              <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{company.industry || <span className="text-gray-400">N/A</span>}</td>
              <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                {company.foundedDate ? new Date(company.foundedDate).toLocaleDateString() : <span className="text-gray-400">N/A</span>}
              </td>
              <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium space-x-2">
                <Link href={\`/companies/\${company.id}/edit\`} passHref>
                  <Button variant="outline" size="sm" className="text-blue-600 border-blue-500 hover:bg-blue-50">
                    <PencilSquareIcon className="h-4 w-4" />
                     <span className="sr-only">Edit</span>
                  </Button>
                </Link>
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => onDelete(company.id)}
                   className="text-red-600 border-red-500 hover:bg-red-50"
                >
                  <TrashIcon className="h-4 w-4" />
                   <span className="sr-only">Delete</span>
                </Button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
EOF_SRC_COMPONENTS_COMPANIES_TABLE_TSX
echo "Created src/components/CompaniesTable.tsx"

# src/components/CompanyForm.tsx
cat << 'EOF_SRC_COMPONENTS_COMPANY_FORM_TSX' > src/components/CompanyForm.tsx
'use client';
import { useForm, SubmitHandler } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Button } from '@/components/ui/button';
import { Company, ICompanyAddress } from '@/types'; // Assuming Company type is suitable for form
import { useEffect, useState } from 'react';

const addressSchema = z.object({
  street: z.string().min(1, 'Street is required').max(100),
  city: z.string().min(1, 'City is required').max(50),
  state: z.string().min(1, 'State is required').max(50),
  postalCode: z.string().min(1, 'Postal Code is required').max(20),
  country: z.string().min(1, 'Country is required').max(50),
}).partial().refine(data => { // Make address optional if all fields are empty
    return Object.values(data).some(val => val && val.trim() !== '');
}, {
    message: "Address requires at least one field if provided.",
    path: [], // General path for the object
}).or(z.undefined());


const companyFormSchema = z.object({
  name: z.string().min(2, 'Company name must be at least 2 characters').max(100),
  contactEmail: z.string().email('Invalid contact email address').max(100),
  industry: z.string().max(100).optional(),
  foundedDate: z.string().optional().refine(val => !val || !isNaN(Date.parse(val)), {
    message: "Invalid date format. Use YYYY-MM-DD.",
  }),
  website: z.string().url('Invalid URL format (e.g., http://example.com)').max(200).optional().or(z.literal('')),
  address: addressSchema,
});

export type CompanyFormData = z.infer<typeof companyFormSchema>;

interface CompanyFormProps {
  onSubmit: SubmitHandler<CompanyFormData>;
  initialData?: Partial<Company>;
  isSubmitting?: boolean;
}

export default function CompanyForm({ onSubmit, initialData, isSubmitting }: CompanyFormProps) {
  const [showAddress, setShowAddress] = useState(!!initialData?.address);

  const { register, handleSubmit, formState: { errors }, reset, watch, setValue } = useForm<CompanyFormData>({
    resolver: zodResolver(companyFormSchema),
    defaultValues: {
      name: initialData?.name || '',
      contactEmail: initialData?.contactEmail || '',
      industry: initialData?.industry || '',
      foundedDate: initialData?.foundedDate ? new Date(initialData.foundedDate).toISOString().split('T')[0] : '',
      website: initialData?.website || '',
      address: initialData?.address || { street: '', city: '', state: '', postalCode: '', country: '' },
    },
  });
  
  useEffect(() => {
    if (initialData) {
      reset({
        name: initialData.name || '',
        contactEmail: initialData.contactEmail || '',
        industry: initialData.industry || '',
        foundedDate: initialData.foundedDate ? new Date(initialData.foundedDate).toISOString().split('T')[0] : '',
        website: initialData.website || '',
        address: initialData.address || { street: '', city: '', state: '', postalCode: '', country: '' },
      });
      setShowAddress(!!initialData.address && Object.values(initialData.address).some(v => v));
    }
  }, [initialData, reset]);

  const watchedAddress = watch("address");
  useEffect(() => {
    if (watchedAddress && Object.values(watchedAddress).some(val => val && String(val).trim() !== '')) {
        setShowAddress(true);
    }
  }, [watchedAddress]);


  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
      <div>
        <Label htmlFor="name">Company Name</Label>
        <Input id="name" {...register('name')} aria-invalid={errors.name ? "true" : "false"} />
        {errors.name && <p role="alert" className="text-red-500 text-sm mt-1">{errors.name.message}</p>}
      </div>

      <div>
        <Label htmlFor="contactEmail">Contact Email</Label>
        <Input id="contactEmail" type="email" {...register('contactEmail')} aria-invalid={errors.contactEmail ? "true" : "false"} />
        {errors.contactEmail && <p role="alert" className="text-red-500 text-sm mt-1">{errors.contactEmail.message}</p>}
      </div>

      <div>
        <Label htmlFor="industry">Industry (Optional)</Label>
        <Input id="industry" {...register('industry')} />
        {errors.industry && <p role="alert" className="text-red-500 text-sm mt-1">{errors.industry.message}</p>}
      </div>

      <div>
        <Label htmlFor="foundedDate">Founded Date (YYYY-MM-DD, Optional)</Label>
        <Input id="foundedDate" type="date" {...register('foundedDate')} aria-invalid={errors.foundedDate ? "true" : "false"} />
        {errors.foundedDate && <p role="alert" className="text-red-500 text-sm mt-1">{errors.foundedDate.message}</p>}
      </div>

      <div>
        <Label htmlFor="website">Website (Optional)</Label>
        <Input id="website" type="url" {...register('website')} placeholder="https://example.com" />
        {errors.website && <p role="alert" className="text-red-500 text-sm mt-1">{errors.website.message}</p>}
      </div>

      <div className="space-y-1">
        {!showAddress ? (
            <Button type="button" variant="outline" onClick={() => setShowAddress(true)}>
                Add Address (Optional)
            </Button>
        ) : (
             <h3 className="text-lg font-medium text-gray-700 pt-2">Address (Optional)</h3>
        )}
      </div>

      {showAddress && (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 p-4 border rounded-md">
            <div>
                <Label htmlFor="address.street">Street</Label>
                <Input id="address.street" {...register('address.street')} />
                {errors.address?.street && <p role="alert" className="text-red-500 text-sm mt-1">{errors.address.street.message}</p>}
            </div>
            <div>
                <Label htmlFor="address.city">City</Label>
                <Input id="address.city" {...register('address.city')} />
                {errors.address?.city && <p role="alert" className="text-red-500 text-sm mt-1">{errors.address.city.message}</p>}
            </div>
            <div>
                <Label htmlFor="address.state">State / Province</Label>
                <Input id="address.state" {...register('address.state')} />
                {errors.address?.state && <p role="alert" className="text-red-500 text-sm mt-1">{errors.address.state.message}</p>}
            </div>
            <div>
                <Label htmlFor="address.postalCode">Postal Code</Label>
                <Input id="address.postalCode" {...register('address.postalCode')} />
                {errors.address?.postalCode && <p role="alert" className="text-red-500 text-sm mt-1">{errors.address.postalCode.message}</p>}
            </div>
            <div className="md:col-span-2">
                <Label htmlFor="address.country">Country</Label>
                <Input id="address.country" {...register('address.country')} />
                {errors.address?.country && <p role="alert" className="text-red-500 text-sm mt-1">{errors.address.country.message}</p>}
            </div>
            {errors.address && !errors.address.street && !errors.address.city && !errors.address.state && !errors.address.postalCode && !errors.address.country && errors.address.message && (
                <p role="alert" className="text-red-500 text-sm mt-1 md:col-span-2">{errors.address.message}</p>
            )}
             <Button type="button" variant="ghost" size="sm" className="md:col-span-2 justify-self-start mt-2" onClick={() => {
                setValue('address', { street: '', city: '', state: '', postalCode: '', country: '' });
                setShowAddress(false);
            }}>
                Clear Address
            </Button>
        </div>
      )}

      <Button type="submit" disabled={isSubmitting} className="w-full sm:w-auto">
         {isSubmitting ? (
            <div className="flex items-center">
                <svg className="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                    <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                    <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                </svg>
                Submitting...
            </div>
        ) : (initialData?.id ? 'Save Changes' : 'Create Company')}
      </Button>
    </form>
  );
}
EOF_SRC_COMPONENTS_COMPANY_FORM_TSX
echo "Created src/components/CompanyForm.tsx"


# --- Lib ---
# src/lib/mongodb.ts
cat << 'EOF_SRC_LIB_MONGODB_TS' > src/lib/mongodb.ts
import mongoose from 'mongoose';

const MONGODB_URI = process.env.MONGODB_URI;

if (!MONGODB_URI) {
  throw new Error('Please define the MONGODB_URI environment variable inside .env or docker-compose.yml');
}

interface MongooseCache {
  conn: typeof mongoose | null;
  promise: Promise<typeof mongoose> | null;
}

// Extend global to include mongoose cache
// Use 'declare global' for global namespace augmentation
declare global {
  // eslint-disable-next-line no-var
  var mongoose_cache: MongooseCache;
}

let cached = global.mongoose_cache;

if (!cached) {
  cached = global.mongoose_cache = { conn: null, promise: null };
}

async function dbConnect(): Promise<typeof mongoose> {
  if (cached.conn) {
    // console.log("Using cached MongoDB connection.");
    return cached.conn;
  }

  if (!cached.promise) {
    const opts = {
      bufferCommands: false, // Disable mongoose buffering (good practice)
      // replicaSet: 'rs0', // Specify replica set if connecting to one directly outside docker-compose networking
    };
    console.log("Attempting new MongoDB connection...");
    cached.promise = mongoose.connect(MONGODB_URI, opts)
      .then((mongooseInstance) => {
        console.log("MongoDB connected successfully.");
        // Initialize models by importing them here if they are not automatically.
        // This is often needed if change streams are set up before any API route using the model is hit.
        import('@/models/Person');
        import('@/models/Company');
        return mongooseInstance;
      })
      .catch(err => {
        console.error("MongoDB connection error:", err);
        cached.promise = null; // Reset promise on error so retry can happen
        throw err;
      });
  }
  try {
    cached.conn = await cached.promise;
  } catch (e) {
    cached.promise = null; // Ensure promise is nulled if connection fails
    throw e;
  }

  return cached.conn;
}

export default dbConnect;
EOF_SRC_LIB_MONGODB_TS
echo "Created src/lib/mongodb.ts"

# src/lib/redis.ts
cat << 'EOF_SRC_LIB_REDIS_TS' > src/lib/redis.ts
import Redis, { RedisOptions } from 'ioredis';

const REDIS_HOST = process.env.REDIS_HOST || 'localhost';
const REDIS_PORT = parseInt(process.env.REDIS_PORT || '6379', 10);

const redisOptions: RedisOptions = {
  host: REDIS_HOST,
  port: REDIS_PORT,
  maxRetriesPerRequest: 3, // Retry a few times for commands
  enableReadyCheck: true, // Default is true, ensure it checks before operations
  retryStrategy: (times) => {
    // Exponential backoff for reconnections
    const delay = Math.min(times * 50, 2000); // Max 2 seconds
    console.warn(`Redis: Retrying connection (attempt ${times}), delay ${delay}ms`);
    return delay;
  },
  // For long-running consumers, you might want to adjust keepAlive
  // keepAlive: 12000, // Send PING every 12 seconds
};

// Singleton instances
let baseClient: Redis | null = null;
let publisherClient: Redis | null = null;
let consumerClient: Redis | null = null;

function createClient(role: string): Redis {
    console.log(`Redis: Creating new ${role} client to ${REDIS_HOST}:${REDIS_PORT}`);
    const client = new Redis(redisOptions);

    client.on('connect', () => console.log(`Redis ${role} Client: Connected to ${REDIS_HOST}:${REDIS_PORT}`));
    client.on('ready', () => console.log(`Redis ${role} Client: Ready`));
    client.on('error', (err) => console.error(`Redis ${role} Client Error:`, err.message, err.stack));
    client.on('close', () => console.log(`Redis ${role} Client: Connection closed`));
    client.on('reconnecting', () => console.log(`Redis ${role} Client: Reconnecting...`));
    client.on('end', () => console.log(`Redis ${role} Client: Connection ended`));
    
    return client;
}


export function getRedisInstance(): Redis {
  if (!baseClient || !baseClient.isOpen) { // isOpen check for ioredis v5+
    if(baseClient && !baseClient.isOpen) baseClient.disconnect(); // Clean up old one if closed
    baseClient = createClient('Base');
  }
  return baseClient;
}

export function getRedisPublisher(): Redis {
  if (!publisherClient || !publisherClient.isOpen) {
    if(publisherClient && !publisherClient.isOpen) publisherClient.disconnect();
    publisherClient = createClient('Publisher');
  }
  return publisherClient;
}

export function getRedisConsumer(): Redis {
   if (!consumerClient || !consumerClient.isOpen) {
    if(consumerClient && !consumerClient.isOpen) consumerClient.disconnect();
    // For consumers, sometimes a dedicated connection with different options might be needed
    // e.g., longer timeouts for blocking reads. For this app, same options are fine.
    consumerClient = createClient('Consumer');
  }
  return consumerClient;
}


// Graceful shutdown for standalone scripts or server termination
// In Next.js, this is harder to manage perfectly due to its lifecycle.
// This is more for if these were run as separate Node.js processes.
let shuttingDown = false;
async function gracefulShutdown(signal: string) {
  if (shuttingDown) return;
  shuttingDown = true;
  console.log(`\nReceived ${signal}. Closing Redis connections...`);
  try {
    if (baseClient && baseClient.isOpen) await baseClient.quit();
    if (publisherClient && publisherClient.isOpen) await publisherClient.quit();
    if (consumerClient && consumerClient.isOpen) await consumerClient.quit();
    console.log('All Redis clients disconnected gracefully.');
  } catch (err) {
    console.error('Error during Redis graceful shutdown:', err);
  } finally {
    process.exit(0);
  }
}

// Only register shutdown hooks if not in a Next.js specific server context
// or if explicitly meant to be a long-running script.
// For Next.js apps, the server handles process termination.
if (process.env.INITIALIZE_BACKGROUND_SERVICES === 'true' && typeof process.env.NEXT_RUNTIME === 'undefined') {
    process.on('SIGINT', () => gracefulShutdown('SIGINT'));
    process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
}
EOF_SRC_LIB_REDIS_TS
echo "Created src/lib/redis.ts"

# src/lib/utils.ts
cat << 'EOF_SRC_LIB_UTILS_TS' > src/lib/utils.ts
import { type ClassValue, clsx } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

// Add other utility functions as needed
export function formatDate(dateString?: string | Date): string {
  if (!dateString) return 'N/A';
  try {
    return new Date(dateString).toLocaleDateString(undefined, {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
    });
  } catch (e) {
    return 'Invalid Date';
  }
}

export function formatDateTime(dateString?: string | Date): string {
  if (!dateString) return 'N/A';
   try {
    return new Date(dateString).toLocaleString(undefined, {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  } catch (e) {
    return 'Invalid Date/Time';
  }
}
EOF_SRC_LIB_UTILS_TS
echo "Created src/lib/utils.ts"

# src/lib/actions.ts (Placeholder, can be used for Server Actions)
cat << 'EOF_SRC_LIB_ACTIONS_TS' > src/lib/actions.ts
'use server';

// This file is a placeholder for Next.js Server Actions.
// You can define server-side functions here that can be called directly from client components.
// Example:
/*
import { revalidatePath } from 'next/cache';

export async function myAction(formData: FormData) {
  // ... perform database operations or other server-side logic
  console.log(formData.get('name'));
  revalidatePath('/some-path'); // Revalidate cache for a specific path
  return { success: true, message: 'Action completed!' };
}
*/

export async function placeholderAction() {
  console.log("Placeholder server action executed.");
  return { message: "This is a placeholder server action." };
}
EOF_SRC_LIB_ACTIONS_TS
echo "Created src/lib/actions.ts"


# --- Models ---
# src/models/Company.ts
cat << 'EOF_SRC_MODELS_COMPANY_TS' > src/models/Company.ts
import mongoose, { Document, Model, Schema, Types } from 'mongoose';

export interface ICompanyAddress {
  street: string;
  city: string;
  state: string;
  postalCode: string;
  country: string;
}

// Interface for the document (excluding virtuals, methods, etc.)
export interface ICompany extends Document {
  _id: Types.ObjectId; // Explicitly define _id
  name: string;
  industry?: string;
  foundedDate?: Date;
  address?: ICompanyAddress;
  contactEmail: string;
  website?: string;
  createdAt: Date;
  updatedAt: Date;
}

const CompanyAddressSchema = new Schema<ICompanyAddress>({
  street: { type: String, required: true, trim: true },
  city: { type: String, required: true, trim: true },
  state: { type: String, required: true, trim: true },
  postalCode: { type: String, required: true, trim: true },
  country: { type: String, required: true, trim: true },
}, { _id: false });

const CompanySchema = new Schema<ICompany>({
  name: { type: String, required: true, unique: true, trim: true, index: true },
  industry: { type: String, trim: true },
  foundedDate: { type: Date },
  address: { type: CompanyAddressSchema, required: false },
  contactEmail: { 
    type: String, 
    required: true, 
    unique: true, 
    trim: true, 
    lowercase: true,
    match: [/.+\@.+\..+/, 'Please fill a valid email address'] 
  },
  website: { type: String, trim: true },
}, { 
  timestamps: true, // Adds createdAt and updatedAt
  toJSON: { 
    virtuals: true, // Ensure virtuals are included
    transform: (doc, ret) => {
      ret.id = ret._id.toString(); // Convert _id to id string
      delete ret._id;
      delete ret.__v;
    }
  },
  toObject: {
    virtuals: true,
    transform: (doc, ret) => {
      ret.id = ret._id.toString();
      delete ret._id;
      delete ret.__v;
    }
  }
});

// Add a virtual 'id' field that returns _id as a string (alternative to transform)
// CompanySchema.virtual('id').get(function() {
//   return this._id.toHexString();
// });


const Company: Model<ICompany> = mongoose.models.Company || mongoose.model<ICompany>('Company', CompanySchema);

export default Company;
EOF_SRC_MODELS_COMPANY_TS
echo "Created src/models/Company.ts"

# src/models/Person.ts
cat << 'EOF_SRC_MODELS_PERSON_TS' > src/models/Person.ts
import mongoose, { Document, Model, Schema, Types } from 'mongoose';
import { ICompany } from './Company'; // Import ICompany for typing the populated field

// Use ICompanyAddress from Company.ts if the structure is identical, or define a new one
export interface IPersonAddress {
  street: string;
  city: string;
  state: string;
  postalCode: string;
  country: string;
}

export interface IPerson extends Document {
  _id: Types.ObjectId; // Explicitly define _id
  name: string;
  email: string;
  birthDate?: Date;
  address?: IPersonAddress;
  phoneNumbers?: string[];
  companyId?: Types.ObjectId | ICompany; // Can be ObjectId or populated ICompany object
  createdAt: Date;
  updatedAt: Date;
}

const PersonAddressSchema = new Schema<IPersonAddress>({
  street: { type: String, required: true, trim: true },
  city: { type: String, required: true, trim: true },
  state: { type: String, required: true, trim: true },
  postalCode: { type: String, required: true, trim: true },
  country: { type: String, required: true, trim: true },
}, { _id: false });

const PersonSchema = new Schema<IPerson>({
  name: { type: String, required: true, trim: true, index: true },
  email: { 
    type: String, 
    required: true, 
    unique: true, 
    trim: true, 
    lowercase: true,
    match: [/.+\@.+\..+/, 'Please fill a valid email address'] 
  },
  birthDate: { type: Date },
  address: { type: PersonAddressSchema, required: false },
  phoneNumbers: [{ type: String, trim: true }],
  companyId: { type: Schema.Types.ObjectId, ref: 'Company', required: false }, // Optional link
}, { 
  timestamps: true,
  toJSON: { 
    virtuals: true,
    transform: (doc, ret) => {
      ret.id = ret._id.toString();
      if (ret.companyId && typeof ret.companyId === 'object' && ret.companyId._id) {
        // If companyId is populated, ensure its id is also a string
        // And structure it as `company: { id: ..., name: ... }` if that's what frontend expects
        // This part needs to align with how you handle population in API routes.
        // For simplicity here, we'll just ensure companyId string if it's an ObjectId
        if (!(ret.companyId instanceof Types.ObjectId)) { // if populated
            ret.company = {id: ret.companyId._id.toString(), name: ret.companyId.name };
            ret.companyId = ret.companyId._id.toString();
        } else {
             ret.companyId = ret.companyId.toString();
        }

      } else if (ret.companyId instanceof Types.ObjectId) {
        ret.companyId = ret.companyId.toString();
      }
      delete ret._id;
      delete ret.__v;
    }
  },
  toObject: { // Similar transformation for toObject if needed
    virtuals: true,
    transform: (doc, ret) => {
      ret.id = ret._id.toString();
      if (ret.companyId && typeof ret.companyId === 'object' && ret.companyId._id) {
         if (!(ret.companyId instanceof Types.ObjectId)) {
            ret.company = {id: ret.companyId._id.toString(), name: ret.companyId.name };
            ret.companyId = ret.companyId._id.toString();
        } else {
             ret.companyId = ret.companyId.toString();
        }
      } else if (ret.companyId instanceof Types.ObjectId) {
        ret.companyId = ret.companyId.toString();
      }
      delete ret._id;
      delete ret.__v;
    }
  }
});


const Person: Model<IPerson> = mongoose.models.Person || mongoose.model<IPerson>('Person', PersonSchema);

export default Person;
EOF_SRC_MODELS_PERSON_TS
echo "Created src/models/Person.ts"

# --- Services ---
# src/services/cdcService.ts
cat << 'EOF_SRC_SERVICES_CDCSERVICE_TS' > src/services/cdcService.ts
import mongoose, { ChangeStreamDocument, ChangeStreamOptions } from 'mongoose';
import { getRedisPublisher } from '@/lib/redis';
import Person from '@/models/Person';
import Company from '@/models/Company';
import dbConnect from '@/lib/mongodb';

const REDIS_CHANGES_STREAM_KEY = 'la:people:changes';
let changeStreamsInitialized = false; // Plural, as we have multiple
const serviceName = "CDCService";

async function publishChangeEvent(
  operationType: string,
  collectionName: string,
  documentId: string | mongoose.Types.ObjectId,
  fullDocument?: any,
  updateDescription?: any
) {
  const redis = getRedisPublisher();
  if (!redis || !redis.isOpen) { // isOpen for ioredis v5+
    console.error(\`[\${serviceName}] Redis publisher not available. Skipping event publication.\`);
    return;
  }

  const eventData: Record<string, string> = { // All XADD values must be strings
    operationType,
    collectionName,
    documentId: documentId.toString(),
    timestamp: new Date().toISOString(),
  };

  if (fullDocument) {
    // Stringify complex objects
    // Be mindful of sensitive data before logging or streaming fullDocument
    const { _id, __v, ...docData } = fullDocument; // Exclude _id and __v if already covered or not needed
    eventData.fullDocument = JSON.stringify(docData);
  }
  if (updateDescription) {
    eventData.updatedFields = JSON.stringify(updateDescription.updatedFields || {});
    eventData.removedFields = JSON.stringify(updateDescription.removedFields || []);
  }


  try {
    // XADD streamName * field1 value1 field2 value2 ...
    const messageArgs: string[] = [];
    for (const [key, value] of Object.entries(eventData)) {
        messageArgs.push(key, value); // Value is already string or stringified
    }

    await redis.xadd(REDIS_CHANGES_STREAM_KEY, '*', ...messageArgs);
    console.log(\`[\${serviceName}] Event published to \${REDIS_CHANGES_STREAM_KEY}: \${operationType} on \${collectionName} (\${documentId})\`);
  } catch (error) {
    console.error(\`[\${serviceName}] Error publishing CDC event to Redis for \${collectionName}:\`, error);
  }
}

export async function initializeChangeStreams() {
  if (changeStreamsInitialized) {
    console.log(\`[\${serviceName}] Change streams already initialized.\`);
    return;
  }
  
  // Guard against running in non-server environments or when disabled
  if (typeof window !== 'undefined' || process.env.INITIALIZE_BACKGROUND_SERVICES !== 'true') {
    console.log(\`[\${serviceName}] Skipping change stream initialization (not in correct environment or disabled).\`);
    return;
  }

  console.log(\`[\${serviceName}] Attempting to initialize MongoDB Change Streams...\`);

  try {
    await dbConnect(); // Ensure DB is connected
    const redis = getRedisPublisher(); // Ensure Redis publisher is connected and ready
    if (!redis || !redis.isOpen) { //isOpen is for ioredis v5+
      console.error(\`[\${serviceName}] Redis publisher not ready. Aborting change stream initialization.\`);
      // Consider retrying or a more robust ready check for Redis
      return; 
    }
  } catch (err) {
    console.error(\`[\${serviceName}] Prerequisite check failed (DB or Redis connection): \`, err);
    return;
  }


  const collectionsToWatch = [
    { model: Person, name: 'people' },
    { model: Company, name: 'companies' },
  ];

  const changeStreamOptions: ChangeStreamOptions = {
    fullDocument: 'updateLookup', // Gets the full document on updates
    fullDocumentBeforeChange: 'off', // 'whenAvailable' or 'required' if you need pre-image
  };

  collectionsToWatch.forEach(collInfo => {
    console.log(\`[\${serviceName}] Setting up change stream for collection: \${collInfo.name}\`);
    const changeStream = collInfo.model.watch([], changeStreamOptions);

    changeStream.on('change', (change: ChangeStreamDocument<any>) => {
      // console.log(\`[\${serviceName}] Change detected in '\${collInfo.name}':\`, change.operationType);
      
      let documentId: string | mongoose.Types.ObjectId;
      let docData: any;
      let updateDesc: any;

      switch (change.operationType) {
        case 'insert':
          documentId = change.fullDocument._id;
          docData = change.fullDocument;
          break;
        case 'update':
          documentId = change.documentKey._id;
          docData = change.fullDocument; // Contains the document *after* the update due to 'updateLookup'
          updateDesc = change.updateDescription;
          break;
        case 'replace': // e.g. findOneAndReplace
            documentId = change.documentKey._id;
            docData = change.fullDocument;
            break;
        case 'delete':
          documentId = change.documentKey._id;
          // For delete, fullDocument is not available in the change event itself.
          // The 'documentKey' (_id) is what's important.
          break;
        default:
          console.log(\`[\${serviceName}] Unhandled change type in '\${collInfo.name}':\`, change.operationType);
          return;
      }
      publishChangeEvent(change.operationType, collInfo.name, documentId, docData, updateDesc);
    });

    changeStream.on('error', (error) => {
      console.error(\`[\${serviceName}] Error in '\${collInfo.name}' change stream:\`, error);
      // Optional: Implement retry logic or attempt to re-establish the stream.
      // For now, we just log it. Mongoose might attempt to reconnect automatically.
      // If it's a "ResumableChangeStreamError", Mongoose usually handles it.
      // If it's "ChangeStream początkowa was killed", it means the cursor died, possibly due to inactivity or server issues.
      if (error.name === 'MongoNetworkError' || error.message.includes('timed out')) {
        console.warn(\`[\${serviceName}] Network error in change stream for \${collInfo.name}. Mongoose might attempt to reconnect.\`);
      } else if (error.code === 280 || error.codeName === 'ChangeStreamKilled') { // ChangeStreamKilled example
        console.warn(\`[\${serviceName}] Change stream for \${collInfo.name} was killed. Attempting to re-initialize might be needed if Mongoose doesn't recover.\`);
        // Consider a mechanism to re-initialize if persistent errors occur.
      }
    });
    
    changeStream.on('close', () => {
        console.log(\`[\${serviceName}] Change stream closed for \${collInfo.name}. This might be due to graceful shutdown or an unrecoverable error.\`);
    });
    
    console.log(\`[\${serviceName}] Change stream listener attached for \${collInfo.name}\`);
  });

  console.log(\`[\${serviceName}] MongoDB Change Streams initialization process completed.\`);
  changeStreamsInitialized = true;
}

// Optional: A function to close streams if needed, though Mongoose might handle this on connection.close()
export async function closeChangeStreams() {
    if (changeStreamsInitialized) {
        // Mongoose change streams are cursors. Closing the mongoose connection should ideally close them.
        // Or, store stream instances and call .close() on each.
        console.log("Closing change streams would typically involve closing Mongoose connection or specific stream instances.");
        changeStreamsInitialized = false;
    }
}
EOF_SRC_SERVICES_CDCSERVICE_TS
echo "Created src/services/cdcService.ts"

# src/services/redisConsumerService.ts
cat << 'EOF_SRC_SERVICES_REDISCONSUMERSERVICE_TS' > src/services/redisConsumerService.ts
import { getRedisConsumer, getRedisInstance } from '@/lib/redis'; // Using getRedisInstance for publishing
import Redis from 'ioredis'; // For type

const SYNC_REQUEST_STREAM_KEY = 'la:people:sync:request';
const CONSUMER_GROUP_NAME = 'app-default-group'; // More descriptive group name
const CONSUMER_NAME_PREFIX = 'peopleapp-consumer'; // Prefix for consumer instances

let consumerInitialized = false;
let isShuttingDown = false; // Flag to manage graceful shutdown
const serviceName = "RedisConsumerService";

// Function to create the consumer group (idempotent)
async function createConsumerGroup(redis: Redis) {
  try {
    // XGROUP CREATE stream_key group_name $ MKSTREAM
    // MKSTREAM creates the stream if it doesn't exist
    // '$' means only new messages arriving after group creation. Use '0' for all history (if stream already exists).
    await redis.xgroup('CREATE', SYNC_REQUEST_STREAM_KEY, CONSUMER_GROUP_NAME, '$', 'MKSTREAM');
    console.log(\`[\${serviceName}] Consumer group '\${CONSUMER_GROUP_NAME}' created or already exists for stream '\${SYNC_REQUEST_STREAM_KEY}'.\`);
  } catch (error: any) {
    if (error.message.includes('BUSYGROUP')) {
      console.log(\`[\${serviceName}] Consumer group '\${CONSUMER_GROUP_NAME}' already exists for stream '\${SYNC_REQUEST_STREAM_KEY}'.\`);
    } else {
      console.error(\`[\${serviceName}] Error creating consumer group '\${CONSUMER_GROUP_NAME}':\`, error);
      // Depending on the error, you might want to retry or throw
      // For now, we log and continue, assuming BUSYGROUP is the common "ignorable" error.
    }
  }
}

async function processMessage(messageId: string, messageData: string[], consumerName: string) {
  console.log(\`[\${consumerName}] Processing message \${messageId} from \${SYNC_REQUEST_STREAM_KEY}:\`);
  const parsedData: Record<string, string> = {};
  for (let i = 0; i < messageData.length; i += 2) {
    parsedData[messageData[i]] = messageData[i + 1];
  }
  console.log(\`[\${consumerName}] Parsed Data:\`, parsedData);

  // TODO: Implement your logic to process the event and write to other queues
  // This is where you'd dispatch tasks based on `parsedData.type` or other fields.
  // Example: Forwarding to another stream/queue based on type
  const eventType = parsedData.type || 'unknown_event';
  const targetQueue = \`downstream:service:\${eventType.toLowerCase().replace(/_ ज़्यादा/g, ':')}\`; // Example: la:sync:user -> downstream:service:user
  
  try {
    const publisher = getRedisInstance(); // Use a general instance for publishing to other queues
    if (!publisher || !publisher.isOpen) {
        console.error(\`[\${consumerName}] Redis publisher not available for forwarding message \${messageId}\`);
        throw new Error("Redis publisher unavailable"); // This will cause message to not be ACKed and retried later
    }
    const forwardPayload = { ...parsedData, processedBy: consumerName, originalMessageId: messageId, processedAt: new Date().toISOString() };
    const messageArgs: string[] = [];
    for (const [key, value] of Object.entries(forwardPayload)) {
        messageArgs.push(key, String(value));
    }
    await publisher.xadd(targetQueue, '*', ...messageArgs);
    console.log(\`[\${consumerName}] Event \${messageId} forwarded to queue: \${targetQueue}\`);
  } catch(error) {
    console.error(\`[\${consumerName}] Failed to forward message \${messageId} to \${targetQueue}:\`, error);
    throw error; // Re-throw to prevent ACK if forwarding is critical
  }


  // Simulate processing time
  // await new Promise(resolve => setTimeout(resolve, Math.random() * 500 + 100)); 
  console.log(\`[\${consumerName}] Finished processing message \${messageId}\`);
}

async function consumeMessages() {
  const consumerName = \`\${CONSUMER_NAME_PREFIX}-\${process.pid}\`;
  let redis: Redis;

  try {
    redis = getRedisConsumer();
    if (!redis || !redis.isOpen) { //isOpen for ioredis v5+
      console.error(\`[\${serviceName}] Redis consumer client not ready. Aborting consumer loop for \${consumerName}.\`);
      return; // Exit if client not ready
    }
    await createConsumerGroup(redis);
  } catch (err) {
     console.error(\`[\${serviceName}] Failed prerequisite for consumer \${consumerName}:\`, err);
     return; // Exit if setup fails
  }


  console.log(\`[\${consumerName}] Starting to listen to stream '\${SYNC_REQUEST_STREAM_KEY}' in group '\${CONSUMER_GROUP_NAME}'...\`);

  while (!isShuttingDown) {
    try {
      // XREADGROUP GROUP group_name consumer_name [COUNT count] [BLOCK milliseconds] STREAMS key [key ...] id [id ...]
      // Using '>' to read new messages that arrive after joining the group.
      // BLOCK 0 means block indefinitely. A timeout (e.g., 5000ms) allows graceful shutdown and periodic checks.
      const response = await redis.xreadgroup(
        'GROUP', CONSUMER_GROUP_NAME, consumerName,
        'COUNT', '10',     // Read up to 10 messages at a time
        'BLOCK', '5000',   // Block for 5 seconds if no messages (adjust as needed)
        'STREAMS', SYNC_REQUEST_STREAM_KEY, '>' // '>' means only new messages for this consumer
      );

      if (isShuttingDown) break; // Check again after potential block

      if (response) {
        // response is an array like: [ [streamName, [ [messageId1, fields1], [messageId2, fields2] ]] ]
        for (const streamMessages of response) {
          // const streamName = streamMessages[0]; // Should be SYNC_REQUEST_STREAM_KEY
          const messages = streamMessages[1] as [string, string[]][]; // Type assertion

          if (messages.length === 0) continue;
          // console.log(\`[\${consumerName}] Received \${messages.length} messages from \${streamName}\`);

          const messageIdsToAck: string[] = [];
          for (const [messageId, messageData] of messages) {
            if (isShuttingDown) break; // Check before processing each message
            try {
              await processMessage(messageId, messageData, consumerName);
              messageIdsToAck.push(messageId);
            } catch (processingError) {
              console.error(\`[\${consumerName}] Error processing message \${messageId}, it will not be ACKed and may be redelivered:\`, processingError);
              // TODO: Implement dead-letter queue (DLQ) logic here if needed
              // e.g., XADD to a DLQ stream, then XACK the original message
            }
          }

          // Acknowledge messages that were successfully processed
          if (messageIdsToAck.length > 0) {
            try {
              await redis.xack(SYNC_REQUEST_STREAM_KEY, CONSUMER_GROUP_NAME, ...messageIdsToAck);
              // console.log(\`[\${consumerName}] Acknowledged \${messageIdsToAck.length} messages.\`);
            } catch (ackError) {
              console.error(\`[\${consumerName}] Error acknowledging messages:\`, ackError, { messageIdsToAck });
              // This is problematic as messages might be reprocessed. Monitor this.
            }
          }
        }
      } else {
        // No messages received, BLOCK timed out. Loop will continue.
        // console.log(\`[\${consumerName}] No new messages from '\${SYNC_REQUEST_STREAM_KEY}', waiting...\`);
      }
    } catch (error: any) {
      if (isShuttingDown) break; // Exit loop if shutting down during an error
      console.error(\`[\${consumerName}] Error reading from stream '\${SYNC_REQUEST_STREAM_KEY}':\`, error.message);
      // Handle specific errors, e.g., connection issues
      if (error.message.includes('NOGROUP')) {
        console.warn(\`[\${consumerName}] Group '\${CONSUMER_GROUP_NAME}' or stream '\${SYNC_REQUEST_STREAM_KEY}' may not exist. Attempting to recreate group...\`);
        await createConsumerGroup(redis); // Attempt to recreate
      }
      // Implement robust retry logic or error handling (e.g., delay before retrying)
      await new Promise(resolve => setTimeout(resolve, 5000)); // Wait 5s before retrying loop
    }
  }
  console.log(\`[\${consumerName}] Consumer loop for '\${SYNC_REQUEST_STREAM_KEY}' is shutting down.\`);
  // Optional: Unregister consumer from group if desired, though usually not necessary
  // await redis.xgroup('DELCONSUMER', SYNC_REQUEST_STREAM_KEY, CONSUMER_GROUP_NAME, consumerName);
}

export async function initializeRedisConsumer() {
  if (consumerInitialized) {
    console.log(\`[\${serviceName}] Redis Stream Consumer already initialized.\`);
    return;
  }
  if (typeof window !== 'undefined' || process.env.INITIALIZE_BACKGROUND_SERVICES !== 'true') {
    console.log(\`[\${serviceName}] Skipping Redis consumer initialization (not in correct environment or disabled).\`);
    return;
  }

  console.log(\`[\${serviceName}] Initializing Redis Stream Consumer...\`);
  consumerInitialized = true;
  isShuttingDown = false; // Reset shutdown flag

  // Start consuming in a non-blocking way
  consumeMessages().catch(err => {
    console.error(\`[\${serviceName}] Redis consumer loop exited with error:\`, err);
    consumerInitialized = false; // Allow re-initialization on next attempt if appropriate
    // Potentially restart or log critical failure
  });
}

export async function stopRedisConsumer() {
    if (consumerInitialized && !isShuttingDown) {
        console.log(\`[\${serviceName}] Attempting to stop Redis Stream Consumer gracefully...\`);
        isShuttingDown = true;
        // The consumer loop will check `isShuttingDown` and exit.
        // You might add a timeout here if needed, or rely on Redis client disconnect.
        // The actual Redis client disconnection is handled in lib/redis.ts gracefulShutdown
    }
}
EOF_SRC_SERVICES_REDISCONSUMERSERVICE_TS
echo "Created src/services/redisConsumerService.ts"


# --- Types ---
# src/types/index.ts
cat << 'EOF_SRC_TYPES_INDEX_TS' > src/types/index.ts
import { ICompany as MongoCompany, ICompanyAddress as MongoCompanyAddress } from '@/models/Company';
import { IPerson as MongoPerson, IPersonAddress as MongoPersonAddress } from '@/models/Person';

// Re-export MongoDB address types if they are suitable for frontend directly
export type ICompanyAddress = MongoCompanyAddress;
export type IPersonAddress = MongoPersonAddress;

// Frontend-friendly Company type
// Omits Mongoose-specific fields like __v, and ensures _id is 'id' as string
// Dates are kept as string to align with form inputs (type="date") and JSON transport
export interface Company extends Omit<MongoCompany, '_id' | 'createdAt' | 'updatedAt' | 'foundedDate' | 'address'> {
  id: string;
  foundedDate?: string; // Dates as string for form inputs (YYYY-MM-DD)
  address?: ICompanyAddress; // Keep address structure
  createdAt: string; // Dates as ISO strings from server
  updatedAt: string;
}

// Frontend-friendly Person type
export interface Person extends Omit<MongoPerson, '_id' | 'createdAt' | 'updatedAt' | 'birthDate' | 'companyId' | 'address'> {
  id: string;
  birthDate?: string; // Dates as string for form inputs (YYYY-MM-DD)
  companyId?: string | null; // ObjectId as string, or null if not set
  company?: { id: string; name: string }; // For populated company data
  address?: IPersonAddress; // Keep address structure
  phoneNumbers?: string[];
  createdAt: string; // Dates as ISO strings from server
  updatedAt: string;
}


export interface PaginatedResponse<T> {
  success: boolean;
  data: T[];
  pagination: {
    currentPage: number;
    totalPages: number;
    totalItems: number;
    itemsPerPage: number;
  };
  error?: string;
}

// Generic API response for single items or mutations
export interface ApiResponse<T = any> {
  success: boolean;
  data?: T;
  error?: string;
  issues?: { path: (string|number)[]; message: string }[]; // For Zod validation issues
}
EOF_SRC_TYPES_INDEX_TS
echo "Created src/types/index.ts"

echo ""
echo "---------------------------------------------------------------------"
echo "Project '$PROJECT_NAME' structure and files created successfully!"
echo "---------------------------------------------------------------------"
echo ""
echo "Next Steps:"
echo "1. Navigate into the project directory if you aren't already:"
echo "   cd $PROJECT_NAME"
echo ""
echo "2. Install dependencies:"
echo "   npm install"
echo "   (or 'pnpm install' or 'yarn install' if you prefer and adapt package.json/Dockerfile)"
echo ""
echo "3. (Optional but Recommended) Initialize Git repository:"
echo "   git init"
echo "   git add ."
echo "   git commit -m \"Initial project setup from script\""
echo ""
echo "4. Build and run the application using Docker Compose:"
echo "   docker-compose up --build -d"
echo "   (The first build might take some time. Add '-d' to run in detached mode.)"
echo ""
echo "5. Access the application in your browser:"
echo "   http://localhost:3000"
echo ""
echo "6. To view logs:"
echo "   docker-compose logs -f app"
echo "   docker-compose logs -f mongo"
echo "   docker-compose logs -f redis-integration-db"
echo ""
echo "7. To stop the application:"
echo "   docker-compose down"
echo ""
echo "Important Notes:"
echo "- The MongoDB service requires replica set initialization for Change Streams."
echo "  The 'mongo-init.js' script handles this on the first run of the 'mongo' container."
echo "  If you encounter issues with Change Streams, check the 'mongo' container logs."
echo "- Background services (CDC, Redis Consumer) are set to initialize based on"
echo "  'INITIALIZE_BACKGROUND_SERVICES=true' in '.env.local' and 'docker-compose.yml'."
echo "- This script provides a comprehensive starting point. You'll likely want to"
echo "  refine UI/UX, add more robust error handling, and expand features."
echo "---------------------------------------------------------------------"

exit 0
```

**How to use this script:**

1.  Save the entire block of code above into a file, for example, `create_full_app.sh`.
2.  Open your terminal or command prompt.
3.  Navigate to the directory where you want to create the `nextjs-mongo-redis-app` project (e.g., `cd ~/Projects`).
4.  Make the script executable: `chmod +x create_full_app.sh`.
5.  Run the script: `./create_full_app.sh`.
6.  The script will create the `nextjs-mongo-redis-app` directory, `cd` into it, and then create all the subdirectories and files with their respective content.
7.  Follow the "Next Steps" printed by the script at the end. Primarily:
    *   `cd nextjs-mongo-redis-app` (if not already in it from script execution)
    *   `npm install`
    *   `docker-compose up --build -d`

This script is quite substantial. Test it in a safe environment first. If you encounter any "command not found" for `cat` or `mkdir`, ensure you are in a bash-compatible environment (like Linux, macOS, or WSL on Windows).  

Okay, this is a very powerful script that will generate the entire project structure and populate all the files with the code we discussed.

**Important Considerations Before Running:**

1.  **Backup:** If you're running this in a directory that has important data, back it up. This script creates a new directory and writes many files.
2.  **Permissions:** You'll need to make the script executable (`chmod +x create_full_app.sh`).
3.  **Dependencies:** This script creates the `package.json`. After it runs, you'll need Node.js and npm (or pnpm/yarn if you modify it) installed to run `npm install`. Docker and Docker Compose are also needed to run the application.
4.  **Length & Potential Typos:** This script is very long. I've tried to be meticulous, but a small typo in a heredoc could cause issues. If you encounter problems, check the console output carefully for errors when the script runs.
5.  **Overwrite:** If the target directory (`nextjs-mongo-redis-app`) already exists, this script will write into it and potentially overwrite existing files with the same names.

Here's the `bash` script:

```bash
#!/bin/bash

PROJECT_NAME="nextjs-mongo-redis-app"

# Check if project directory already exists
if [ -d "$PROJECT_NAME" ]; then
  echo "Directory '$PROJECT_NAME' already exists."
  read -p "Do you want to overwrite or add files to it? (y/N): " confirm
  if [[ "$confirm" != [yY] && "$confirm" != [yY][eE][sS] ]]; then
    echo "Aborted by user."
    exit 1
  fi
else
  mkdir -p "$PROJECT_NAME"
  echo "Created directory '$PROJECT_NAME'."
fi

cd "$PROJECT_NAME" || { echo "Failed to cd into $PROJECT_NAME"; exit 1; }

echo "Creating project structure and files for '$PROJECT_NAME'..."

# --- Root Files ---

# .env.local
cat << 'EOF_ENV_LOCAL' > .env.local
MONGODB_URI=mongodb://localhost:27017/people_app
REDIS_HOST=localhost
REDIS_PORT=6379
NEXT_PUBLIC_API_BASE_URL=http://localhost:3000/api

# For Change Stream and Consumer to run, they need to be initialized.
# Set to true when running in a long-lived server environment (like the Docker container)
# Set to false or remove if deploying to serverless where background tasks are handled differently.
INITIALIZE_BACKGROUND_SERVICES=true
EOF_ENV_LOCAL
echo "Created .env.local"

# .gitignore
cat << 'EOF_GITIGNORE' > .gitignore
# See https://help.github.com/articles/ignoring-files/ for more about ignoring files.

# Dependencies
/node_modules
/.pnp
.pnp.js
.yarn/

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
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*
pnpm-debug.log*

# Local Env Files
.env
.env*.local
!.env.example

# IDE / Editor
.vscode/
.idea/
*.swp
*~
EOF_GITIGNORE
echo "Created .gitignore"

# docker-compose.yml
cat << 'EOF_DOCKER_COMPOSE' > docker-compose.yml
version: '3.8'

services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "3000:3000"
    depends_on:
      mongo:
        condition: service_healthy # Wait for mongo to be healthy
      redis-integration-db:
        condition: service_healthy # Wait for redis to be healthy
    environment:
      - MONGODB_URI=mongodb://mongo:27017/people_app
      - REDIS_HOST=redis-integration-db
      - REDIS_PORT=6379
      - NEXT_PUBLIC_API_BASE_URL=http://app:3000/api # Internal for server-side, adjust if client needs external
      - NODE_ENV=development # Change to production for prod builds
      - INITIALIZE_BACKGROUND_SERVICES=true # Ensure background services run in Docker
    volumes:
      - .:/app # Mount current directory to /app in container for dev
      - /app/node_modules # Don't mount host node_modules
      - /app/.next # Don't mount host .next
    restart: unless-stopped
    networks:
      - app-network
    healthcheck: # Optional: check if the Next.js app is responsive
      test: ["CMD", "curl", "-f", "http://localhost:3000/api/health"] # Add a /api/health endpoint
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s # Give time for app to start

  mongo:
    image: mongo:latest
    ports:
      - "27017:27017"
    volumes:
      - mongo-data:/data/db
      - ./mongo-init.js:/docker-entrypoint-initdb.d/mongo-init.js:ro # For replica set init
    networks:
      - app-network
    restart: unless-stopped
    command: mongod --replSet rs0 --bind_ip_all # Required for change streams
    healthcheck:
      test: echo 'db.runCommand("ping").ok' | mongosh localhost:27017/test --quiet
      interval: 10s
      timeout: 10s
      retries: 5
      start_period: 10s

  redis-integration-db:
    image: redis:latest
    ports:
      - "6379:6379"
    command: redis-server --appendonly yes
    volumes:
      - redis-data:/data
    networks:
      - app-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  mongo-data:
  redis-data:

networks:
  app-network:
    driver: bridge
EOF_DOCKER_COMPOSE
echo "Created docker-compose.yml"

# mongo-init.js (for replica set initialization, required for change streams)
cat << 'EOF_MONGO_INIT_JS' > mongo-init.js
try {
  rs.status();
  print("Replica set already initialized.");
} catch (e) {
  if (e.codeName === 'NotYetInitialized') {
    print("Initializing replica set...");
    rs.initiate({
      _id: "rs0",
      members: [
        { _id: 0, host: "mongo:27017" }
      ]
    });
    print("Replica set initialized.");

    // Wait for replica set to be ready (primary elected)
    let isMaster = false;
    let retries = 30; // Try for 30 seconds
    while (!isMaster && retries > 0) {
      print("Waiting for primary to be elected...");
      sleep(1000); // Sleep for 1 second (mongosh syntax)
      let status = rs.status();
      if (status.myState === 1) { // 1 indicates PRIMARY
        isMaster = true;
        print("Primary elected.");
      }
      retries--;
    }
    if (!isMaster) {
      print("Failed to elect primary in time.");
      // exit(1); // or throw error if critical
    }

  } else {
    print("Error checking replica set status: " + e);
    // throw e; // Re-throw other errors
  }
}
EOF_MONGO_INIT_JS
echo "Created mongo-init.js"


# Dockerfile
cat << 'EOF_DOCKERFILE' > Dockerfile
# 1. Install dependencies only when needed
FROM node:20-alpine AS deps
WORKDIR /app

COPY package.json package-lock.json* ./
# Use npm ci for faster, more reliable builds if package-lock.json is committed
# If package-lock.json might not exist, use npm install
RUN npm ci || npm install --legacy-peer-deps

# 2. Rebuild the source code only when needed
FROM node:20-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Next.js collects completely anonymous telemetry data about general usage.
# Learn more here: https://nextjs.org/telemetry
ENV NEXT_TELEMETRY_DISABLED 1

RUN npm run build

# 3. Production image, copy all the files and run next
FROM node:20-alpine AS runner
WORKDIR /app

ENV NODE_ENV production
ENV NEXT_TELEMETRY_DISABLED 1

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public

# Automatically leverage output traces to reduce image size
# https://nextjs.org/docs/advanced-features/output-file-tracing
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000
ENV PORT 3000

# Add a basic health check endpoint if you add one to your app
# CMD ["node", "server.js"] will be used by default with output: 'standalone'

CMD ["node", "server.js"]
EOF_DOCKERFILE
echo "Created Dockerfile"

# next.config.mjs
cat << 'EOF_NEXT_CONFIG' > next.config.mjs
/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone', // Important for Docker optimized build
  experimental: {
    // Required for Change Streams and Redis Consumer long-running processes
    // This allows these packages to be bundled correctly.
    serverComponentsExternalPackages: ['mongoose', 'ioredis'],
  },
  // If you need to ensure certain files are copied to standalone output
  // outputTraceIncludes: ['./src/services/**'], // Example
};

export default nextConfig;
EOF_NEXT_CONFIG
echo "Created next.config.mjs"

# package.json
cat << 'EOF_PACKAGE_JSON' > package.json
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
    "@heroicons/react": "^2.1.3",
    "clsx": "^2.1.0",
    "ioredis": "^5.4.1",
    "mongoose": "^8.3.2",
    "next": "14.2.3",
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "react-hook-form": "^7.51.4",
    "tailwind-merge": "^2.3.0",
    "zod": "^3.23.6"
  },
  "devDependencies": {
    "@types/mongoose": "^5.11.97",
    "@types/node": "^20.12.7",
    "@types/react": "^18.3.1",
    "@types/react-dom": "^18.3.0",
    "autoprefixer": "^10.4.19",
    "eslint": "^8.57.0",
    "eslint-config-next": "14.2.3",
    "postcss": "^8.4.38",
    "tailwindcss": "^3.4.3",
    "typescript": "^5.4.5"
  }
}
EOF_PACKAGE_JSON
echo "Created package.json"

# tsconfig.json
cat << 'EOF_TSCONFIG_JSON' > tsconfig.json
{
  "compilerOptions": {
    "target": "es5",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "forceConsistentCasingInFileNames": true,
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
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
EOF_TSCONFIG_JSON
echo "Created tsconfig.json"

# postcss.config.js
cat << 'EOF_POSTCSS_CONFIG' > postcss.config.js
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
EOF_POSTCSS_CONFIG
echo "Created postcss.config.js"

# tailwind.config.ts
cat << 'EOF_TAILWIND_CONFIG' > tailwind.config.ts
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
EOF_TAILWIND_CONFIG
echo "Created tailwind.config.ts"

# README.md
cat << 'EOF_README_MD' > README.md
# Next.js, MongoDB, and Redis Fullstack App

This application demonstrates CRUD operations for 'People' and 'Companies' collections in MongoDB,
with change data capture to a Redis stream, and a Redis stream consumer.

## Setup

1.  Ensure Docker and Docker Compose are installed.
2.  Ensure Node.js and npm (or pnpm/yarn) are installed.
3.  Run `npm install` (or your package manager's install command) to install dependencies.
4.  The `mongo-init.js` script will attempt to initialize a replica set for MongoDB, which is necessary for Change Streams.
5.  Build and start the services: `docker-compose up --build -d`.
    *   It might take a moment for MongoDB to initialize the replica set on the first run. Check `docker-compose logs mongo`.
6.  Access the app at `http://localhost:3000`.

## Features

-   CRUD for People (UI and API)
-   CRUD for Companies (UI and API)
-   MongoDB Change Data Capture (CDC) publishing events to Redis Stream `la:people:changes`.
-   Redis Stream Consumer listening to `la:people:sync:request` (consumer group `app-group`).

## Tech Stack

-   Next.js (v14+ with App Router)
-   TypeScript
-   MongoDB (latest stable) & Mongoose
-   Redis (latest stable) & ioredis
-   Tailwind CSS
-   React Hook Form & Zod (for frontend forms)
-   Docker & Docker Compose

## Testing Background Services

### MongoDB Change Data Capture (CDC)

1.  Perform any CRUD operation via the UI (e.g., add a new person).
2.  Check the application logs: `docker-compose logs -f app`. You should see "CDC Event Published..."
3.  You can also inspect the Redis stream directly:
    ```bash
    docker-compose exec redis-integration-db redis-cli
    # Inside redis-cli:
    XRANGE la:people:changes - +
    ```

### Redis Stream Consumer (`la:people:sync:request`)

This app *consumes* from this stream. To test it, you need to *publish* a message to it.

1.  Ensure the app is running (`docker-compose up -d`).
2.  Publish a message using `redis-cli`:
    ```bash
    docker-compose exec redis-integration-db redis-cli
    # Inside redis-cli:
    XADD la:people:sync:request * type "test_sync" entityId "E123" details "{\"action\":\"process_me\"}"
    ```
3.  Check the application logs: `docker-compose logs -f app`. You should see the consumer pick up and process this message.

## Environment Variables

Configure in `.env.local` (for local Next.js dev outside Docker) or in `docker-compose.yml` for the `app` service.

-   `MONGODB_URI`: MongoDB connection string.
-   `REDIS_HOST`: Redis host.
-   `REDIS_PORT`: Redis port.
-   `NEXT_PUBLIC_API_BASE_URL`: Base URL for client-side API calls.
-   `INITIALIZE_BACKGROUND_SERVICES`: Set to `true` to enable CDC and Redis consumer initialization.

## Notes

-   The MongoDB service in `docker-compose.yml` is configured to run as a single-node replica set (`rs0`) because MongoDB Change Streams require a replica set. The `mongo-init.js` script handles this initialization.
-   The background services (CDC listener, Redis consumer) are initialized within the Next.js application process. In a larger production system, these might be separate microservices.
EOF_README_MD
echo "Created README.md"

# --- src directory ---
mkdir -p src/app/api/companies/[id]
mkdir -p src/app/api/people/[id]
mkdir -p src/app/api/health # For health check
mkdir -p src/app/companies/new
mkdir -p src/app/companies/[id]/edit
mkdir -p src/app/people/new
mkdir -p src/app/people/[id]/edit
mkdir -p src/components/ui
mkdir -p src/lib
mkdir -p src/models
mkdir -p src/services
mkdir -p src/types
echo "Created src subdirectories"

# src/app/globals.css
cat << 'EOF_SRC_APP_GLOBALS_CSS' > src/app/globals.css
@tailwind base;
@tailwind components;
@tailwind utilities;

/* Add any global styles here */
body {
  @apply bg-slate-50 text-slate-800;
}
EOF_SRC_APP_GLOBALS_CSS
echo "Created src/app/globals.css"

# src/app/layout.tsx
cat << 'EOF_SRC_APP_LAYOUT_TSX' > src/app/layout.tsx
import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";
import Navbar from "@/components/Navbar";

// IMPORTANT: Conditional initialization for background services
// This ensures they only run on the server and ideally once per server instance.
if (typeof window === 'undefined' && process.env.INITIALIZE_BACKGROUND_SERVICES === 'true' && process.env.NODE_ENV !== 'production' || (process.env.NODE_ENV === 'production' && process.env.NEXT_RUNTIME !== 'edge')) {
  // Dynamically import and initialize to avoid issues during build or in client components
  (async () => {
    try {
      console.log("Layout: Attempting to initialize background services...");
      const { initializeChangeStreams } = await import("@/services/cdcService");
      const { initializeRedisConsumer } = await import("@/services/redisConsumerService");
      
      // These functions should be idempotent
      await initializeChangeStreams();
      await initializeRedisConsumer();
      console.log("Layout: Background services initialization sequence called.");
    } catch (error) {
      console.error("Layout: Error initializing background services:", error);
    }
  })();
} else if (typeof window === 'undefined') {
  console.log("Layout: Skipping background service initialization (INITIALIZE_BACKGROUND_SERVICES not true, or edge runtime, or prod build without specific check).");
}


const inter = Inter({ subsets: ["latin"] });

export const metadata: Metadata = {
  title: "People & Companies App",
  description: "Manage People and Companies with MongoDB and Redis",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className={`${inter.className} min-h-screen flex flex-col`}>
        <Navbar />
        <main className="container mx-auto p-4 flex-grow">
          {children}
        </main>
        <footer className="bg-gray-800 text-white text-center p-4">
          <p>&copy; 2024 PeopleApp Inc.</p>
        </footer>
      </body>
    </html>
  );
}
EOF_SRC_APP_LAYOUT_TSX
echo "Created src/app/layout.tsx"

# src/app/page.tsx
cat << 'EOF_SRC_APP_PAGE_TSX' > src/app/page.tsx
import Link from 'next/link';
import { Button } from '@/components/ui/button'; // Assuming Button component exists

export default function HomePage() {
  return (
    <div className="text-center py-10">
      <h1 className="text-4xl font-bold mb-6 text-gray-800">Welcome to PeopleApp</h1>
      <p className="text-lg text-gray-600 mb-8">
        Efficiently manage your people and company records.
      </p>
      <div className="space-x-4">
        <Link href="/people" passHref>
          <Button size="lg">Manage People</Button>
        </Link>
        <Link href="/companies" passHref>
          <Button size="lg" variant="secondary">Manage Companies</Button>
        </Link>
      </div>
      <div className="mt-12 p-6 bg-white shadow-lg rounded-lg">
        <h2 className="text-2xl font-semibold mb-3 text-gray-700">Key Features</h2>
        <ul className="list-disc list-inside text-left mx-auto max-w-md text-gray-600">
          <li>Full CRUD operations for People and Companies.</li>
          <li>Real-time database change tracking via MongoDB Change Streams.</li>
          <li>Integration with Redis for event-driven architecture.</li>
          <li>Responsive and modern user interface.</li>
          <li>Containerized with Docker for easy deployment.</li>
        </ul>
      </div>
    </div>
  );
}
EOF_SRC_APP_PAGE_TSX
echo "Created src/app/page.tsx"

# --- API Routes ---
# src/app/api/health/route.ts
cat << 'EOF_SRC_API_HEALTH_ROUTE_TS' > src/app/api/health/route.ts
import { NextResponse } from 'next/server';
import dbConnect from '@/lib/mongodb';
import { getRedisInstance } from '@/lib/redis';

export async function GET() {
  let dbStatus = 'disconnected';
  let redisStatus = 'disconnected';

  try {
    await dbConnect();
    // Basic check, like counting documents in a small collection or a ping
    // For simplicity, if dbConnect doesn't throw, we assume basic connectivity.
    // mongoose.connection.db.admin().ping() is more robust.
    if (dbConnect && global.mongoose?.conn?.readyState === 1) {
        dbStatus = 'connected';
    }
  } catch (error) {
    console.error("Health Check: MongoDB connection error", error);
    dbStatus = 'error';
  }

  try {
    const redis = getRedisInstance();
    const pingResponse = await redis.ping();
    if (pingResponse === "PONG") {
      redisStatus = 'connected';
    }
  } catch (error) {
    console.error("Health Check: Redis connection error", error);
    redisStatus = 'error';
  }

  const healthStatus = {
    status: 'ok',
    timestamp: new Date().toISOString(),
    mongodb: dbStatus,
    redis: redisStatus,
  };

  if (dbStatus !== 'connected' || redisStatus !== 'connected') {
    return NextResponse.json(healthStatus, { status: 503 }); // Service Unavailable
  }

  return NextResponse.json(healthStatus);
}
EOF_SRC_API_HEALTH_ROUTE_TS
echo "Created src/app/api/health/route.ts"

# src/app/api/companies/route.ts
cat << 'EOF_SRC_API_COMPANIES_ROUTE_TS' > src/app/api/companies/route.ts
import { NextRequest, NextResponse } from 'next/server';
import dbConnect from '@/lib/mongodb';
import Company, { ICompany } from '@/models/Company';
import { z } from 'zod';

// Zod schema for validation
const companySchema = z.object({
  name: z.string().min(1, "Name is required"),
  contactEmail: z.string().email("Invalid email format"),
  industry: z.string().optional(),
  foundedDate: z.string().optional().refine(val => !val || !isNaN(Date.parse(val)), {
    message: "Invalid date format for foundedDate",
  }),
  website: z.string().url().optional().or(z.literal('')),
  address: z.object({
    street: z.string().min(1, "Street is required"),
    city: z.string().min(1, "City is required"),
    state: z.string().min(1, "State is required"),
    postalCode: z.string().min(1, "Postal code is required"),
    country: z.string().min(1, "Country is required"),
  }).optional(),
});


export async function GET(req: NextRequest) {
  await dbConnect();
  try {
    const { searchParams } = new URL(req.url);
    const page = parseInt(searchParams.get('page') || '1', 10);
    const limit = parseInt(searchParams.get('limit') || '10', 10);
    const skip = (page - 1) * limit;

    const companies = await Company.find({})
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit)
      .lean();

    const totalCompanies = await Company.countDocuments();
    
    return NextResponse.json({ 
      success: true, 
      data: companies.map(c => ({...c, id: c._id.toString()})), // Ensure id is string
      pagination: {
        currentPage: page,
        totalPages: Math.ceil(totalCompanies / limit),
        totalItems: totalCompanies,
        itemsPerPage: limit
      }
    });
  } catch (error: any) {
    return NextResponse.json({ success: false, error: error.message }, { status: 500 });
  }
}

export async function POST(req: NextRequest) {
  await dbConnect();
  try {
    const body = await req.json();
    const validation = companySchema.safeParse(body);

    if (!validation.success) {
      return NextResponse.json({ success: false, error: "Validation failed", issues: validation.error.issues }, { status: 400 });
    }
    
    const newCompanyData: Partial<ICompany> = validation.data;
    if (validation.data.foundedDate) {
      newCompanyData.foundedDate = new Date(validation.data.foundedDate);
    }


    const newCompany = await Company.create(newCompanyData);
    return NextResponse.json({ success: true, data: {...newCompany.toObject(), id: newCompany._id.toString()} }, { status: 201 });
  } catch (error: any) {
    if (error.code === 11000) { // Duplicate key error
        const field = Object.keys(error.keyPattern)[0];
        return NextResponse.json({ success: false, error: `Company with this ${field} already exists.` }, { status: 409 });
    }
    return NextResponse.json({ success: false, error: error.message }, { status: 400 });
  }
}
EOF_SRC_API_COMPANIES_ROUTE_TS
echo "Created src/app/api/companies/route.ts"

# src/app/api/companies/[id]/route.ts
cat << 'EOF_SRC_API_COMPANIES_ID_ROUTE_TS' > src/app/api/companies/[id]/route.ts
import { NextRequest, NextResponse } from 'next/server';
import dbConnect from '@/lib/mongodb';
import Company, { ICompany } from '@/models/Company';
import Person from '@/models/Person'; // To handle company deletion impact
import { z } from 'zod';

// Zod schema for updates (all fields optional)
const companyUpdateSchema = z.object({
  name: z.string().min(1, "Name is required").optional(),
  contactEmail: z.string().email("Invalid email format").optional(),
  industry: z.string().optional(),
  foundedDate: z.string().optional().refine(val => !val || !isNaN(Date.parse(val)), {
    message: "Invalid date format for foundedDate",
  }),
  website: z.string().url().optional().or(z.literal('')),
  address: z.object({
    street: z.string().min(1, "Street is required"),
    city: z.string().min(1, "City is required"),
    state: z.string().min(1, "State is required"),
    postalCode: z.string().min(1, "Postal code is required"),
    country: z.string().min(1, "Country is required"),
  }).optional(),
}).partial(); // Makes all fields optional for PUT

export async function GET(req: NextRequest, { params }: { params: { id: string } }) {
  await dbConnect();
  try {
    const company = await Company.findById(params.id).lean();
    if (!company) {
      return NextResponse.json({ success: false, error: 'Company not found' }, { status: 404 });
    }
    return NextResponse.json({ success: true, data: {...company, id: company._id.toString()} });
  } catch (error: any) {
    if (error.name === 'CastError') {
        return NextResponse.json({ success: false, error: 'Invalid company ID format' }, { status: 400 });
    }
    return NextResponse.json({ success: false, error: error.message }, { status: 500 });
  }
}

export async function PUT(req: NextRequest, { params }: { params: { id: string } }) {
  await dbConnect();
  try {
    const body = await req.json();
    const validation = companyUpdateSchema.safeParse(body);

    if (!validation.success) {
      return NextResponse.json({ success: false, error: "Validation failed", issues: validation.error.issues }, { status: 400 });
    }

    const updateData: Partial<ICompany> = { ...validation.data };
    if (validation.data.foundedDate) {
      updateData.foundedDate = new Date(validation.data.foundedDate);
    }
     // Handle case where address might be explicitly set to null or undefined to remove it
    if (body.hasOwnProperty('address') && !body.address) {
        updateData.address = undefined;
    }


    const updatedCompany = await Company.findByIdAndUpdate(params.id, updateData, {
      new: true,
      runValidators: true,
    }).lean();

    if (!updatedCompany) {
      return NextResponse.json({ success: false, error: 'Company not found' }, { status: 404 });
    }
    return NextResponse.json({ success: true, data: {...updatedCompany, id: updatedCompany._id.toString()} });
  } catch (error: any) {
    if (error.name === 'CastError') {
        return NextResponse.json({ success: false, error: 'Invalid company ID format' }, { status: 400 });
    }
    if (error.code === 11000) { // Duplicate key error
        const field = Object.keys(error.keyPattern)[0];
        return NextResponse.json({ success: false, error: `Company with this ${field} already exists.` }, { status: 409 });
    }
    return NextResponse.json({ success: false, error: error.message }, { status: 400 });
  }
}

export async function DELETE(req: NextRequest, { params }: { params: { id: string } }) {
  await dbConnect();
  try {
    // Optional: Check if any person is associated with this company
    const associatedPeopleCount = await Person.countDocuments({ companyId: params.id });
    if (associatedPeopleCount > 0) {
      return NextResponse.json({ 
        success: false, 
        error: `Cannot delete company. ${associatedPeopleCount} people are associated with it. Please reassign or delete them first.` 
      }, { status: 409 }); // Conflict
    }

    const deletedCompany = await Company.findByIdAndDelete(params.id);
    if (!deletedCompany) {
      return NextResponse.json({ success: false, error: 'Company not found' }, { status: 404 });
    }
    return NextResponse.json({ success: true, data: { id: params.id, message: 'Company deleted' } });
  } catch (error: any) {
    if (error.name === 'CastError') {
        return NextResponse.json({ success: false, error: 'Invalid company ID format' }, { status: 400 });
    }
    return NextResponse.json({ success: false, error: error.message }, { status: 500 });
  }
}
EOF_SRC_API_COMPANIES_ID_ROUTE_TS
echo "Created src/app/api/companies/[id]/route.ts"

# src/app/api/people/route.ts
cat << 'EOF_SRC_API_PEOPLE_ROUTE_TS' > src/app/api/people/route.ts
import { NextRequest, NextResponse } from 'next/server';
import dbConnect from '@/lib/mongodb';
import Person, { IPerson } from '@/models/Person';
import Company from '@/models/Company'; // Import Company to ensure it's registered for population
import { z } from 'zod';

// Zod schema for Person creation
const personSchema = z.object({
  name: z.string().min(1, "Name is required"),
  email: z.string().email("Invalid email format"),
  birthDate: z.string().optional().refine(val => !val || !isNaN(Date.parse(val)), {
    message: "Invalid date format for birthDate",
  }),
  address: z.object({
    street: z.string().min(1, "Street is required"),
    city: z.string().min(1, "City is required"),
    state: z.string().min(1, "State is required"),
    postalCode: z.string().min(1, "Postal code is required"),
    country: z.string().min(1, "Country is required"),
  }).optional(),
  phoneNumbers: z.array(z.string()).optional(),
  companyId: z.string().optional().nullable(), // Allow null or ObjectId string
});


export async function GET(req: NextRequest) {
  await dbConnect();
  // Ensure Company model is initialized if populate is used
  // A simple way to do this is to perform a trivial operation.
  await Company.findOne({_id: null}).catch(() => {}); // No-op to ensure model is loaded


  try {
    const { searchParams } = new URL(req.url);
    const page = parseInt(searchParams.get('page') || '1', 10);
    const limit = parseInt(searchParams.get('limit') || '10', 10);
    const skip = (page - 1) * limit;

    const peopleQuery = Person.find({})
      .populate('companyId', 'name id') // Populate company name and its string id
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit);
    
    // Using .lean() makes the query faster and returns plain JavaScript objects.
    // However, Mongoose virtuals defined with getters/setters on the schema might not work as expected with .lean()
    // if they depend on `this` being a Mongoose document instance.
    // For simple population and direct field access, .lean() is fine.
    // If you have complex virtuals, you might omit .lean() or ensure they work with plain objects.
    const people = await peopleQuery.lean();


    const totalPeople = await Person.countDocuments();
    
    const formattedPeople = people.map(p => ({
        ...p,
        id: p._id.toString(),
        companyId: p.companyId ? (typeof p.companyId === 'string' ? p.companyId : (p.companyId as any)._id?.toString()) : undefined,
        company: p.companyId && (p.companyId as any).name ? { id: (p.companyId as any)._id?.toString(), name: (p.companyId as any).name } : undefined
    }));

    return NextResponse.json({ 
      success: true, 
      data: formattedPeople,
      pagination: {
        currentPage: page,
        totalPages: Math.ceil(totalPeople / limit),
        totalItems: totalPeople,
        itemsPerPage: limit
      }
    });
  } catch (error: any) {
    console.error("Error fetching people:", error);
    return NextResponse.json({ success: false, error: error.message }, { status: 500 });
  }
}

export async function POST(req: NextRequest) {
  await dbConnect();
  try {
    const body = await req.json();
    const validation = personSchema.safeParse(body);

    if (!validation.success) {
      return NextResponse.json({ success: false, error: "Validation failed", issues: validation.error.issues }, { status: 400 });
    }
    
    const personData: Partial<IPerson> = { ...validation.data };
    if (validation.data.birthDate) {
      personData.birthDate = new Date(validation.data.birthDate);
    }
    if (validation.data.companyId === "" || validation.data.companyId === null) {
      personData.companyId = undefined; // Store as undefined if empty string or null
    } else if (validation.data.companyId) {
      personData.companyId = validation.data.companyId as any; // Mongoose will cast string to ObjectId
    }


    const newPerson = await Person.create(personData);
    // Repopulate after creation if needed, or structure the response carefully
    const populatedPerson = await Person.findById(newPerson._id).populate('companyId', 'name id').lean();

    return NextResponse.json({ 
        success: true, 
        data: {
            ...populatedPerson,
            id: populatedPerson!._id.toString(),
            companyId: populatedPerson!.companyId ? (populatedPerson!.companyId as any)._id?.toString() : undefined,
            company: populatedPerson!.companyId && (populatedPerson!.companyId as any).name ? { id: (populatedPerson!.companyId as any)._id?.toString(), name: (populatedPerson!.companyId as any).name } : undefined
        }
    }, { status: 201 });

  } catch (error: any) {
    if (error.code === 11000) { // Duplicate key error
        const field = Object.keys(error.keyPattern)[0];
        return NextResponse.json({ success: false, error: `Person with this ${field} already exists.` }, { status: 409 });
    }
    console.error("Error creating person:", error);
    return NextResponse.json({ success: false, error: error.message }, { status: 400 });
  }
}
EOF_SRC_API_PEOPLE_ROUTE_TS
echo "Created src/app/api/people/route.ts"

# src/app/api/people/[id]/route.ts
cat << 'EOF_SRC_API_PEOPLE_ID_ROUTE_TS' > src/app/api/people/[id]/route.ts
import { NextRequest, NextResponse } from 'next/server';
import dbConnect from '@/lib/mongodb';
import Person, { IPerson } from '@/models/Person';
import Company from '@/models/Company'; // For population
import { z } from 'zod';

// Zod schema for Person update (all fields optional)
const personUpdateSchema = z.object({
  name: z.string().min(1, "Name is required").optional(),
  email: z.string().email("Invalid email format").optional(),
  birthDate: z.string().optional().refine(val => !val || !isNaN(Date.parse(val)), {
    message: "Invalid date format for birthDate",
  }),
  address: z.object({
    street: z.string().min(1, "Street is required"),
    city: z.string().min(1, "City is required"),
    state: z.string().min(1, "State is required"),
    postalCode: z.string().min(1, "Postal code is required"),
    country: z.string().min(1, "Country is required"),
  }).optional().nullable(),
  phoneNumbers: z.array(z.string()).optional(),
  companyId: z.string().optional().nullable(), // Allow null, empty string (for unsetting), or ObjectId string
}).partial(); // Makes all fields optional

export async function GET(req: NextRequest, { params }: { params: { id: string } }) {
  await dbConnect();
  await Company.findOne({_id: null}).catch(() => {}); // Ensure Company model is initialized for population

  try {
    const person = await Person.findById(params.id).populate('companyId', 'name id').lean();
    if (!person) {
      return NextResponse.json({ success: false, error: 'Person not found' }, { status: 404 });
    }
    const formattedPerson = {
        ...person,
        id: person._id.toString(),
        companyId: person.companyId ? (typeof person.companyId === 'string' ? person.companyId : (person.companyId as any)._id?.toString()) : undefined,
        company: person.companyId && (person.companyId as any).name ? { id: (person.companyId as any)._id?.toString(), name: (person.companyId as any).name } : undefined
    };
    return NextResponse.json({ success: true, data: formattedPerson });
  } catch (error: any) {
     if (error.name === 'CastError') {
        return NextResponse.json({ success: false, error: 'Invalid person ID format' }, { status: 400 });
    }
    console.error("Error fetching person by ID:", error);
    return NextResponse.json({ success: false, error: error.message }, { status: 500 });
  }
}

export async function PUT(req: NextRequest, { params }: { params: { id: string } }) {
  await dbConnect();
  try {
    const body = await req.json();
    const validation = personUpdateSchema.safeParse(body);

    if (!validation.success) {
      return NextResponse.json({ success: false, error: "Validation failed", issues: validation.error.issues }, { status: 400 });
    }
    
    const updateData: Partial<IPerson> = { ...validation.data };
    if (validation.data.birthDate) {
      updateData.birthDate = new Date(validation.data.birthDate);
    }
    // Handle companyId: if empty string or null, set to undefined to remove association
    if (validation.data.companyId === "" || validation.data.companyId === null) {
      updateData.companyId = undefined;
    } else if (validation.data.companyId) {
      updateData.companyId = validation.data.companyId as any; // Mongoose will cast
    }

    // Handle case where address might be explicitly set to null or undefined to remove it
    if (body.hasOwnProperty('address') && !body.address) {
        updateData.address = undefined;
    }


    const updatedPersonDoc = await Person.findByIdAndUpdate(params.id, { $set: updateData } , {
      new: true,
      runValidators: true,
    }).populate('companyId', 'name id'); // Populate after update

    if (!updatedPersonDoc) {
      return NextResponse.json({ success: false, error: 'Person not found' }, { status: 404 });
    }

    const populatedPerson = updatedPersonDoc.toObject(); // Convert to plain object to attach id string

    return NextResponse.json({ 
        success: true, 
        data: {
            ...populatedPerson,
            id: populatedPerson._id.toString(),
            companyId: populatedPerson.companyId ? (populatedPerson.companyId as any)._id?.toString() : undefined,
            company: populatedPerson.companyId && (populatedPerson.companyId as any).name ? { id: (populatedPerson.companyId as any)._id?.toString(), name: (populatedPerson.companyId as any).name } : undefined
        }
    });
  } catch (error: any)
   {
    if (error.name === 'CastError') {
        return NextResponse.json({ success: false, error: 'Invalid person ID format or company ID format' }, { status: 400 });
    }
     if (error.code === 11000) { // Duplicate key error
        const field = Object.keys(error.keyPattern)[0];
        return NextResponse.json({ success: false, error: `Person with this ${field} already exists.` }, { status: 409 });
    }
    console.error("Error updating person:", error);
    return NextResponse.json({ success: false, error: error.message }, { status: 400 });
  }
}

export async function DELETE(req: NextRequest, { params }: { params: { id: string } }) {
  await dbConnect();
  try {
    const deletedPerson = await Person.findByIdAndDelete(params.id);
    if (!deletedPerson) {
      return NextResponse.json({ success: false, error: 'Person not found' }, { status: 404 });
    }
    return NextResponse.json({ success: true, data: { id: params.id, message: 'Person deleted' } });
  } catch (error: any) {
    if (error.name === 'CastError') {
        return NextResponse.json({ success: false, error: 'Invalid person ID format' }, { status: 400 });
    }
    console.error("Error deleting person:", error);
    return NextResponse.json({ success: false, error: error.message }, { status: 500 });
  }
}
EOF_SRC_API_PEOPLE_ID_ROUTE_TS
echo "Created src/app/api/people/[id]/route.ts"


# --- Frontend Page Components (People) ---
# src/app/people/page.tsx
cat << 'EOF_SRC_APP_PEOPLE_PAGE_TSX' > src/app/people/page.tsx
'use client';

import { useState, useEffect, useCallback } from 'react';
import Link from 'next/link';
import PeopleTable from '@/components/PeopleTable';
import { Button } from '@/components/ui/button';
import { Person, PaginatedResponse } from '@/types';
import { PlusCircleIcon } from '@heroicons/react/24/outline';

const API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL || '/api';

export default function PeoplePage() {
  const [people, setPeople] = useState<Person[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [pagination, setPagination] = useState({ currentPage: 1, totalPages: 1, totalItems: 0, itemsPerPage: 10});
  const [searchTerm, setSearchTerm] = useState(''); // Basic search example

  const fetchPeople = useCallback(async (page = 1, limit = 10, search = '') => {
    setIsLoading(true);
    setError(null);
    try {
      // TODO: Implement search on backend if needed, this is just a placeholder for client-side or future backend search
      const response = await fetch(\`\${API_BASE_URL}/people?page=\${page}&limit=\${limit}\${search ? '&q='+search : ''}\`);
      if (!response.ok) {
        const errData = await response.json();
        throw new Error(errData.error || \`Failed to fetch people: \${response.statusText}\`);
      }
      const result: PaginatedResponse<Person> = await response.json();
      if (result.success) {
        setPeople(result.data);
        setPagination(result.pagination);
      } else {
        throw new Error(result.error || 'Unknown error fetching people');
      }
    } catch (err: any) {
      setError(err.message);
      setPeople([]);
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchPeople(pagination.currentPage, pagination.itemsPerPage, searchTerm);
  }, [fetchPeople, pagination.currentPage, pagination.itemsPerPage, searchTerm]);

  const handleDeletePerson = async (id: string) => {
    if (!confirm('Are you sure you want to delete this person? This action cannot be undone.')) return;
    try {
      const response = await fetch(\`\${API_BASE_URL}/people/\${id}\`, { method: 'DELETE' });
      if (!response.ok) {
        const errData = await response.json();
        throw new Error(errData.error || 'Failed to delete person');
      }
      alert('Person deleted successfully');
      // Re-fetch current page or if last item on page, go to previous page
      if (people.length === 1 && pagination.currentPage > 1) {
        handlePageChange(pagination.currentPage - 1);
      } else {
        fetchPeople(pagination.currentPage, pagination.itemsPerPage, searchTerm);
      }
    } catch (err: any) {
      setError(err.message);
      alert(\`Error: \${err.message}\`);
    }
  };
  
  const handlePageChange = (newPage: number) => {
    if (newPage >= 1 && newPage <= pagination.totalPages && newPage !== pagination.currentPage) {
      setPagination(prev => ({ ...prev, currentPage: newPage }));
    }
  };

  return (
    <div className="space-y-6 p-4 md:p-6 bg-white shadow-xl rounded-lg">
      <div className="flex flex-col sm:flex-row justify-between items-center gap-4">
        <h1 className="text-3xl font-bold text-gray-800">Manage People</h1>
        <Link href="/people/new" passHref>
          <Button className="w-full sm:w-auto">
            <PlusCircleIcon className="h-5 w-5 mr-2" />
            Add New Person
          </Button>
        </Link>
      </div>

      {/* Basic Search Input - TODO: Debounce and implement backend search for real app */}
      {/* <div className="my-4">
        <Input 
          type="text"
          placeholder="Search people..."
          value={searchTerm}
          onChange={(e) => setSearchTerm(e.target.value)}
          className="max-w-sm"
        />
      </div> */}

      {isLoading && <div className="flex justify-center items-center p-10"><div className="loader ease-linear rounded-full border-4 border-t-4 border-gray-200 h-12 w-12 mb-4"></div><p className="text-gray-600">Loading people...</p></div>}
      {error && <div role="alert" className="p-4 mb-4 text-sm text-red-700 bg-red-100 rounded-lg"><span className="font-medium">Error:</span> {error}</div>}
      
      {!isLoading && !error && (
        <>
          <PeopleTable people={people} onDelete={handleDeletePerson} />
          {pagination.totalItems > 0 && pagination.totalPages > 1 && (
            <div className="mt-6 flex flex-col sm:flex-row justify-between items-center text-sm text-gray-600">
              <p>Showing {((pagination.currentPage - 1) * pagination.itemsPerPage) + 1} - {Math.min(pagination.currentPage * pagination.itemsPerPage, pagination.totalItems)} of {pagination.totalItems} people</p>
              <div className="flex items-center space-x-2 mt-2 sm:mt-0">
                <Button 
                  onClick={() => handlePageChange(1)} 
                  disabled={pagination.currentPage === 1}
                  variant="outline"
                  size="sm"
                >
                  First
                </Button>
                <Button 
                  onClick={() => handlePageChange(pagination.currentPage - 1)} 
                  disabled={pagination.currentPage === 1}
                  variant="outline"
                  size="sm"
                >
                  Previous
                </Button>
                <span className="px-2">Page {pagination.currentPage} of {pagination.totalPages}</span>
                <Button 
                  onClick={() => handlePageChange(pagination.currentPage + 1)} 
                  disabled={pagination.currentPage === pagination.totalPages}
                  variant="outline"
                  size="sm"
                >
                  Next
                </Button>
                 <Button 
                  onClick={() => handlePageChange(pagination.totalPages)} 
                  disabled={pagination.currentPage === pagination.totalPages}
                  variant="outline"
                  size="sm"
                >
                  Last
                </Button>
              </div>
            </div>
          )}
           {!isLoading && !error && people.length === 0 && (
             <p className="text-center text-gray-500 py-8">No people found. Try adding some!</p>
           )}
        </>
      )}
    </div>
  );
}
EOF_SRC_APP_PEOPLE_PAGE_TSX
echo "Created src/app/people/page.tsx"

# src/app/people/new/page.tsx
cat << 'EOF_SRC_APP_PEOPLE_NEW_PAGE_TSX' > src/app/people/new/page.tsx
'use client';
import PersonForm from '@/components/PersonForm';
import { PersonFormData } from '@/components/PersonForm'; // Assuming PersonForm exports this type
import { useRouter } from 'next/navigation';
import { useState } from 'react';
import { ArrowLeftIcon } from '@heroicons/react/24/outline';
import Link from 'next/link';

const API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL || '/api';

export default function NewPersonPage() {
  const router = useRouter();
  const [error, setError] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleSubmit = async (data: PersonFormData) => {
    setIsSubmitting(true);
    setError(null);
    try {
      // Ensure companyId is null if empty, or string if selected
      const payload = {
        ...data,
        companyId: data.companyId === '' ? null : data.companyId,
        // Convert empty strings in address to undefined if address itself is provided
        address: data.address && Object.values(data.address).some(v => v) ? data.address : undefined,
        phoneNumbers: data.phoneNumbers?.filter(p => p.trim() !== '') || [],
      };

      const response = await fetch(\`\${API_BASE_URL}/people\`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });
      
      const result = await response.json();

      if (!response.ok) {
        throw new Error(result.error || 'Failed to create person. ' + (result.issues ? JSON.stringify(result.issues) : ''));
      }
      
      alert('Person created successfully!');
      router.push('/people');
    } catch (err: any) {
      setError(err.message);
      alert(\`Error: \${err.message}\`);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="max-w-2xl mx-auto p-4 md:p-6 bg-white shadow-xl rounded-lg">
      <Link href="/people" className="inline-flex items-center text-blue-600 hover:text-blue-800 mb-6">
        <ArrowLeftIcon className="h-5 w-5 mr-2" />
        Back to People List
      </Link>
      <h1 className="text-3xl font-bold text-gray-800 mb-6">Add New Person</h1>
      {error && <div role="alert" className="p-4 mb-4 text-sm text-red-700 bg-red-100 rounded-lg"><span className="font-medium">Error:</span> {error}</div>}
      <PersonForm onSubmit={handleSubmit} isSubmitting={isSubmitting} />
    </div>
  );
}
EOF_SRC_APP_PEOPLE_NEW_PAGE_TSX
echo "Created src/app/people/new/page.tsx"

# src/app/people/[id]/edit/page.tsx
cat << 'EOF_SRC_APP_PEOPLE_ID_EDIT_PAGE_TSX' > src/app/people/[id]/edit/page.tsx
'use client';
import PersonForm from '@/components/PersonForm';
import { PersonFormData } from '@/components/PersonForm';
import { Person } from '@/types';
import { useRouter, useParams } from 'next/navigation';
import { useState, useEffect, useCallback } from 'react';
import { ArrowLeftIcon } from '@heroicons/react/24/outline';
import Link from 'next/link';

const API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL || '/api';

export default function EditPersonPage() {
  const router = useRouter();
  const params = useParams();
  const id = params.id as string;

  const [person, setPerson] = useState<Person | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const fetchPerson = useCallback(async () => {
    if (!id) return;
    setIsLoading(true);
    setError(null);
    try {
      const response = await fetch(\`\${API_BASE_URL}/people/\${id}\`);
      if (!response.ok) {
        const errData = await response.json();
        throw new Error(errData.error || 'Failed to fetch person details');
      }
      const result = await response.json();
      if (result.success) {
        // Transform data for the form, e.g., date format if necessary
        const fetchedPerson = result.data;
        if (fetchedPerson.birthDate) {
          fetchedPerson.birthDate = new Date(fetchedPerson.birthDate).toISOString().split('T')[0];
        }
        setPerson(fetchedPerson);
      } else {
        throw new Error(result.error || 'Error in API response');
      }
    } catch (err: any) {
      setError(err.message);
      setPerson(null);
    } finally {
      setIsLoading(false);
    }
  }, [id]);

  useEffect(() => {
    fetchPerson();
  }, [fetchPerson]);

  const handleSubmit = async (data: PersonFormData) => {
    if (!id) return;
    setIsSubmitting(true);
    setError(null);
    try {
      const payload = {
        ...data,
        companyId: data.companyId === '' ? null : data.companyId,
        address: data.address && Object.values(data.address).some(v => v) ? data.address : undefined,
        phoneNumbers: data.phoneNumbers?.filter(p => p.trim() !== '') || [],
      };

      const response = await fetch(\`\${API_BASE_URL}/people/\${id}\`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });
      const result = await response.json();
      if (!response.ok) {
        throw new Error(result.error || 'Failed to update person. ' + (result.issues ? JSON.stringify(result.issues) : ''));
      }
      alert('Person updated successfully!');
      router.push('/people');
    } catch (err: any) {
      setError(err.message);
      alert(\`Error: \${err.message}\`);
    } finally {
      setIsSubmitting(false);
    }
  };

  if (isLoading) return <div className="flex justify-center items-center p-10"><div className="loader ease-linear rounded-full border-4 border-t-4 border-gray-200 h-12 w-12 mb-4"></div><p className="text-gray-600">Loading person details...</p></div>;
  if (error && !person) return <div role="alert" className="p-4 m-4 text-sm text-red-700 bg-red-100 rounded-lg"><span className="font-medium">Error:</span> {error}. <Link href="/people" className="font-semibold underline hover:text-red-800">Go back to list.</Link></div>;
  if (!person) return <p className="text-center text-gray-500 py-8">Person not found.</p>;

  return (
    <div className="max-w-2xl mx-auto p-4 md:p-6 bg-white shadow-xl rounded-lg">
      <Link href="/people" className="inline-flex items-center text-blue-600 hover:text-blue-800 mb-6">
        <ArrowLeftIcon className="h-5 w-5 mr-2" />
        Back to People List
      </Link>
      <h1 className="text-3xl font-bold text-gray-800 mb-6">Edit Person: {person.name}</h1>
      {error && <div role="alert" className="p-4 mb-4 text-sm text-red-700 bg-red-100 rounded-lg"><span className="font-medium">Error during submission:</span> {error}</div>}
      <PersonForm onSubmit={handleSubmit} initialData={person} isSubmitting={isSubmitting} />
    </div>
  );
}
EOF_SRC_APP_PEOPLE_ID_EDIT_PAGE_TSX
echo "Created src/app/people/[id]/edit/page.tsx"


# --- Frontend Page Components (Companies) ---
# src/app/companies/page.tsx
cat << 'EOF_SRC_APP_COMPANIES_PAGE_TSX' > src/app/companies/page.tsx
'use client';

import { useState, useEffect, useCallback } from 'react';
import Link from 'next/link';
import CompaniesTable from '@/components/CompaniesTable';
import { Button } from '@/components/ui/button';
import { Company, PaginatedResponse } from '@/types';
import { PlusCircleIcon } from '@heroicons/react/24/outline';

const API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL || '/api';

export default function CompaniesPage() {
  const [companies, setCompanies] = useState<Company[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [pagination, setPagination] = useState({ currentPage: 1, totalPages: 1, totalItems: 0, itemsPerPage: 10});

  const fetchCompanies = useCallback(async (page = 1, limit = 10) => {
    setIsLoading(true);
    setError(null);
    try {
      const response = await fetch(\`\${API_BASE_URL}/companies?page=\${page}&limit=\${limit}\`);
      if (!response.ok) {
        const errData = await response.json();
        throw new Error(errData.error || \`Failed to fetch companies: \${response.statusText}\`);
      }
      const result: PaginatedResponse<Company> = await response.json();
      if (result.success) {
        setCompanies(result.data);
        setPagination(result.pagination);
      } else {
        throw new Error(result.error || 'Unknown error fetching companies');
      }
    } catch (err: any) {
      setError(err.message);
      setCompanies([]);
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchCompanies(pagination.currentPage, pagination.itemsPerPage);
  }, [fetchCompanies, pagination.currentPage, pagination.itemsPerPage]);

  const handleDeleteCompany = async (id: string) => {
    if (!confirm('Are you sure you want to delete this company? This may affect associated people if not handled on the backend.')) return;
    try {
      const response = await fetch(\`\${API_BASE_URL}/companies/\${id}\`, { method: 'DELETE' });
      const result = await response.json();
      if (!response.ok) {
        throw new Error(result.error || 'Failed to delete company');
      }
      alert('Company deleted successfully');
      if (companies.length === 1 && pagination.currentPage > 1) {
        handlePageChange(pagination.currentPage - 1);
      } else {
        fetchCompanies(pagination.currentPage, pagination.itemsPerPage);
      }
    } catch (err: any) {
      setError(err.message);
      alert(\`Error: \${err.message}\`);
    }
  };
  
  const handlePageChange = (newPage: number) => {
    if (newPage >= 1 && newPage <= pagination.totalPages && newPage !== pagination.currentPage) {
      setPagination(prev => ({ ...prev, currentPage: newPage }));
    }
  };

  return (
    <div className="space-y-6 p-4 md:p-6 bg-white shadow-xl rounded-lg">
      <div className="flex flex-col sm:flex-row justify-between items-center gap-4">
        <h1 className="text-3xl font-bold text-gray-800">Manage Companies</h1>
        <Link href="/companies/new" passHref>
          <Button className="w-full sm:w-auto">
             <PlusCircleIcon className="h-5 w-5 mr-2" />
            Add New Company
          </Button>
        </Link>
      </div>

      {isLoading && <div className="flex justify-center items-center p-10"><div className="loader ease-linear rounded-full border-4 border-t-4 border-gray-200 h-12 w-12 mb-4"></div><p className="text-gray-600">Loading companies...</p></div>}
      {error && <div role="alert" className="p-4 mb-4 text-sm text-red-700 bg-red-100 rounded-lg"><span className="font-medium">Error:</span> {error}</div>}
      
      {!isLoading && !error && (
        <>
          <CompaniesTable companies={companies} onDelete={handleDeleteCompany} />
           {pagination.totalItems > 0 && pagination.totalPages > 1 && (
            <div className="mt-6 flex flex-col sm:flex-row justify-between items-center text-sm text-gray-600">
              <p>Showing {((pagination.currentPage - 1) * pagination.itemsPerPage) + 1} - {Math.min(pagination.currentPage * pagination.itemsPerPage, pagination.totalItems)} of {pagination.totalItems} companies</p>
              <div className="flex items-center space-x-2 mt-2 sm:mt-0">
                <Button 
                  onClick={() => handlePageChange(1)} 
                  disabled={pagination.currentPage === 1}
                  variant="outline"
                  size="sm"
                >
                  First
                </Button>
                <Button 
                  onClick={() => handlePageChange(pagination.currentPage - 1)} 
                  disabled={pagination.currentPage === 1}
                  variant="outline"
                  size="sm"
                >
                  Previous
                </Button>
                <span className="px-2">Page {pagination.currentPage} of {pagination.totalPages}</span>
                <Button 
                  onClick={() => handlePageChange(pagination.currentPage + 1)} 
                  disabled={pagination.currentPage === pagination.totalPages}
                  variant="outline"
                  size="sm"
                >
                  Next
                </Button>
                 <Button 
                  onClick={() => handlePageChange(pagination.totalPages)} 
                  disabled={pagination.currentPage === pagination.totalPages}
                  variant="outline"
                  size="sm"
                >
                  Last
                </Button>
              </div>
            </div>
          )}
          {!isLoading && !error && companies.length === 0 && (
             <p className="text-center text-gray-500 py-8">No companies found. Try adding some!</p>
           )}
        </>
      )}
    </div>
  );
}
EOF_SRC_APP_COMPANIES_PAGE_TSX
echo "Created src/app/companies/page.tsx"

# src/app/companies/new/page.tsx
cat << 'EOF_SRC_APP_COMPANIES_NEW_PAGE_TSX' > src/app/companies/new/page.tsx
'use client';
import CompanyForm from '@/components/CompanyForm';
import { CompanyFormData } from '@/components/CompanyForm';
import { useRouter } from 'next/navigation';
import { useState } from 'react';
import { ArrowLeftIcon } from '@heroicons/react/24/outline';
import Link from 'next/link';

const API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL || '/api';

export default function NewCompanyPage() {
  const router = useRouter();
  const [error, setError] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleSubmit = async (data: CompanyFormData) => {
    setIsSubmitting(true);
    setError(null);
    try {
      // Convert empty strings in address to undefined if address itself is provided
      const payload = {
        ...data,
        address: data.address && Object.values(data.address).some(v => v) ? data.address : undefined,
      };

      const response = await fetch(\`\${API_BASE_URL}/companies\`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });
      const result = await response.json();
      if (!response.ok) {
        throw new Error(result.error || 'Failed to create company. ' + (result.issues ? JSON.stringify(result.issues) : ''));
      }
      alert('Company created successfully!');
      router.push('/companies');
    } catch (err: any) {
      setError(err.message);
      alert(\`Error: \${err.message}\`);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="max-w-2xl mx-auto p-4 md:p-6 bg-white shadow-xl rounded-lg">
      <Link href="/companies" className="inline-flex items-center text-blue-600 hover:text-blue-800 mb-6">
        <ArrowLeftIcon className="h-5 w-5 mr-2" />
        Back to Companies List
      </Link>
      <h1 className="text-3xl font-bold text-gray-800 mb-6">Add New Company</h1>
      {error && <div role="alert" className="p-4 mb-4 text-sm text-red-700 bg-red-100 rounded-lg"><span className="font-medium">Error:</span> {error}</div>}
      <CompanyForm onSubmit={handleSubmit} isSubmitting={isSubmitting} />
    </div>
  );
}
EOF_SRC_APP_COMPANIES_NEW_PAGE_TSX
echo "Created src/app/companies/new/page.tsx"

# src/app/companies/[id]/edit/page.tsx
cat << 'EOF_SRC_APP_COMPANIES_ID_EDIT_PAGE_TSX' > src/app/companies/[id]/edit/page.tsx
'use client';
import CompanyForm from '@/components/CompanyForm';
import { CompanyFormData } from '@/components/CompanyForm';
import { Company } from '@/types';
import { useRouter, useParams } from 'next/navigation';
import { useState, useEffect, useCallback } from 'react';
import { ArrowLeftIcon } from '@heroicons/react/24/outline';
import Link from 'next/link';

const API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL || '/api';

export default function EditCompanyPage() {
  const router = useRouter();
  const params = useParams();
  const id = params.id as string;

  const [company, setCompany] = useState<Company | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const fetchCompany = useCallback(async () => {
    if (!id) return;
    setIsLoading(true);
    setError(null);
    try {
      const response = await fetch(\`\${API_BASE_URL}/companies/\${id}\`);
      if (!response.ok) {
         const errData = await response.json();
        throw new Error(errData.error || 'Failed to fetch company details');
      }
      const result = await response.json();
      if (result.success) {
        const fetchedCompany = result.data;
        // Format date for input type="date"
        if (fetchedCompany.foundedDate) {
          fetchedCompany.foundedDate = new Date(fetchedCompany.foundedDate).toISOString().split('T')[0];
        }
        setCompany(fetchedCompany);
      } else {
        throw new Error(result.error || 'Error in API response');
      }
    } catch (err: any) {
      setError(err.message);
      setCompany(null);
    } finally {
      setIsLoading(false);
    }
  }, [id]);

  useEffect(() => {
    fetchCompany();
  }, [fetchCompany]);

  const handleSubmit = async (data: CompanyFormData) => {
    if (!id) return;
    setIsSubmitting(true);
    setError(null);
    try {
      const payload = {
        ...data,
        address: data.address && Object.values(data.address).some(v => v) ? data.address : undefined,
      };

      const response = await fetch(\`\${API_BASE_URL}/companies/\${id}\`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });
      const result = await response.json();
      if (!response.ok) {
        throw new Error(result.error || 'Failed to update company. ' + (result.issues ? JSON.stringify(result.issues) : ''));
      }
      alert('Company updated successfully!');
      router.push('/companies');
    } catch (err: any) {
      setError(err.message);
      alert(\`Error: \${err.message}\`);
    } finally {
      setIsSubmitting(false);
    }
  };

  if (isLoading) return <div className="flex justify-center items-center p-10"><div className="loader ease-linear rounded-full border-4 border-t-4 border-gray-200 h-12 w-12 mb-4"></div><p className="text-gray-600">Loading company details...</p></div>;
  if (error && !company) return <div role="alert" className="p-4 m-4 text-sm text-red-700 bg-red-100 rounded-lg"><span className="font-medium">Error:</span> {error}. <Link href="/companies" className="font-semibold underline hover:text-red-800">Go back to list.</Link></div>;
  if (!company) return <p className="text-center text-gray-500 py-8">Company not found.</p>;

  return (
    <div className="max-w-2xl mx-auto p-4 md:p-6 bg-white shadow-xl rounded-lg">
      <Link href="/companies" className="inline-flex items-center text-blue-600 hover:text-blue-800 mb-6">
        <ArrowLeftIcon className="h-5 w-5 mr-2" />
        Back to Companies List
      </Link>
      <h1 className="text-3xl font-bold text-gray-800 mb-6">Edit Company: {company.name}</h1>
       {error && <div role="alert" className="p-4 mb-4 text-sm text-red-700 bg-red-100 rounded-lg"><span className="font-medium">Error during submission:</span> {error}</div>}
      <CompanyForm onSubmit={handleSubmit} initialData={company} isSubmitting={isSubmitting} />
    </div>
  );
}
EOF_SRC_APP_COMPANIES_ID_EDIT_PAGE_TSX
echo "Created src/app/companies/[id]/edit/page.tsx"


# --- UI Components ---
# src/components/ui/button.tsx
cat << 'EOF_SRC_COMPONENTS_UI_BUTTON_TSX' > src/components/ui/button.tsx
import React from 'react';
import { Slot } from '@radix-ui/react-slot';
import { cva, type VariantProps } from 'class-variance-authority';
import { cn } from '@/lib/utils'; // Assuming you have a cn utility

const buttonVariants = cva(
  'inline-flex items-center justify-center rounded-md text-sm font-medium ring-offset-background transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50',
  {
    variants: {
      variant: {
        default: 'bg-blue-600 text-primary-foreground hover:bg-blue-600/90 text-white',
        destructive:
          'bg-red-600 text-destructive-foreground hover:bg-red-600/90 text-white',
        outline:
          'border border-input bg-background hover:bg-accent hover:text-accent-foreground',
        secondary:
          'bg-slate-200 text-secondary-foreground hover:bg-slate-200/80',
        ghost: 'hover:bg-accent hover:text-accent-foreground',
        link: 'text-primary underline-offset-4 hover:underline',
      },
      size: {
        default: 'h-10 px-4 py-2',
        sm: 'h-9 rounded-md px-3',
        lg: 'h-11 rounded-md px-8',
        icon: 'h-10 w-10',
      },
    },
    defaultVariants: {
      variant: 'default',
      size: 'default',
    },
  }
);

export interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {
  asChild?: boolean;
}

const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant, size, asChild = false, ...props }, ref) => {
    const Comp = asChild ? Slot : 'button';
    return (
      <Comp
        className={cn(buttonVariants({ variant, size, className }))}
        ref={ref}
        {...props}
      />
    );
  }
);
Button.displayName = 'Button';

export { Button, buttonVariants };
EOF_SRC_COMPONENTS_UI_BUTTON_TSX
echo "Created src/components/ui/button.tsx"

# src/components/ui/input.tsx
cat << 'EOF_SRC_COMPONENTS_UI_INPUT_TSX' > src/components/ui/input.tsx
import * as React from 'react';
import { cn } from '@/lib/utils'; // Assuming you have a cn utility

export interface InputProps
  extends React.InputHTMLAttributes<HTMLInputElement> {}

const Input = React.forwardRef<HTMLInputElement, InputProps>(
  ({ className, type, ...props }, ref) => {
    return (
      <input
        type={type}
        className={cn(
          'flex h-10 w-full rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background file:border-0 file:bg-transparent file:text-sm file:font-medium placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50',
          'border-gray-300 focus:border-blue-500 focus:ring-blue-500', // Custom styling
          className
        )}
        ref={ref}
        {...props}
      />
    );
  }
);
Input.displayName = 'Input';

export { Input };
EOF_SRC_COMPONENTS_UI_INPUT_TSX
echo "Created src/components/ui/input.tsx"

# src/components/ui/label.tsx
cat << 'EOF_SRC_COMPONENTS_UI_LABEL_TSX' > src/components/ui/label.tsx
'use client';
import * as React from 'react';
import * as LabelPrimitive from '@radix-ui/react-label';
import { cva, type VariantProps } from 'class-variance-authority';
import { cn } from '@/lib/utils'; // Assuming you have a cn utility

const labelVariants = cva(
  'text-sm font-medium leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70'
);

const Label = React.forwardRef<
  React.ElementRef<typeof LabelPrimitive.Root>,
  React.ComponentPropsWithoutRef<typeof LabelPrimitive.Root> &
    VariantProps<typeof labelVariants>
>(({ className, ...props }, ref) => (
  <LabelPrimitive.Root
    ref={ref}
    className={cn(labelVariants(), 'block text-gray-700 mb-1', className)} // Custom styling
    {...props}
  />
));
Label.displayName = LabelPrimitive.Root.displayName;

export { Label };
EOF_SRC_COMPONENTS_UI_LABEL_TSX
echo "Created src/components/ui/label.tsx"

# src/components/ui/textarea.tsx
cat << 'EOF_SRC_COMPONENTS_UI_TEXTAREA_TSX' > src/components/ui/textarea.tsx
import * as React from "react"
import { cn } from "@/lib/utils"

export interface TextareaProps
  extends React.TextareaHTMLAttributes<HTMLTextAreaElement> {}

const Textarea = React.forwardRef<HTMLTextAreaElement, TextareaProps>(
  ({ className, ...props }, ref) => {
    return (
      <textarea
        className={cn(
          "flex min-h-[80px] w-full rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50",
          "border-gray-300 focus:border-blue-500 focus:ring-blue-500", // Custom styling
          className
        )}
        ref={ref}
        {...props}
      />
    )
  }
)
Textarea.displayName = "Textarea"

export { Textarea }
EOF_SRC_COMPONENTS_UI_TEXTAREA_TSX
echo "Created src/components/ui/textarea.tsx"

# src/components/ui/modal.tsx (Basic example, can be expanded)
cat << 'EOF_SRC_COMPONENTS_UI_MODAL_TSX' > src/components/ui/modal.tsx
'use client';
import React, { ReactNode } from 'react';

interface ModalProps {
  isOpen: boolean;
  onClose: () => void;
  title?: string;
  children: ReactNode;
}

export default function Modal({ isOpen, onClose, title, children }: ModalProps) {
  if (!isOpen) return null;

  return (
    <div 
      className="fixed inset-0 bg-black bg-opacity-50 z-50 flex justify-center items-center p-4"
      onClick={onClose} // Close on overlay click
    >
      <div 
        className="bg-white p-6 rounded-lg shadow-xl max-w-lg w-full"
        onClick={(e) => e.stopPropagation()} // Prevent close when clicking inside modal content
      >
        {title && <h2 className="text-xl font-semibold mb-4 text-gray-800">{title}</h2>}
        <div>{children}</div>
        <div className="mt-6 flex justify-end">
          <button
            onClick={onClose}
            className="px-4 py-2 bg-gray-200 text-gray-700 rounded-md hover:bg-gray-300 transition"
          >
            Close
          </button>
        </div>
      </div>
    </div>
  );
}
EOF_SRC_COMPONENTS_UI_MODAL_TSX
echo "Created src/components/ui/modal.tsx"

# src/components/Navbar.tsx
cat << 'EOF_SRC_COMPONENTS_NAVBAR_TSX' > src/components/Navbar.tsx
'use client';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { HomeIcon, UserGroupIcon, BuildingOffice2Icon } from '@heroicons/react/24/solid'; // Using solid icons

const navLinks = [
  { href: '/', label: 'Home', icon: HomeIcon },
  { href: '/people', label: 'People', icon: UserGroupIcon },
  { href: '/companies', label: 'Companies', icon: BuildingOffice2Icon },
];

export default function Navbar() {
  const pathname = usePathname();

  return (
    <nav className="bg-gray-800 text-white shadow-lg sticky top-0 z-50">
      <div className="container mx-auto px-4">
        <div className="flex items-center justify-between h-16">
          <Link href="/" className="text-2xl font-bold hover:text-gray-300 transition-colors">
            PeopleApp
          </Link>
          <div className="flex space-x-2 md:space-x-4">
            {navLinks.map(({ href, label, icon: Icon }) => {
              const isActive = pathname === href || (href !== '/' && pathname.startsWith(href));
              return (
                <Link
                  key={label}
                  href={href}
                  className={`flex items-center px-3 py-2 rounded-md text-sm font-medium transition-all
                    ${isActive
                      ? 'bg-gray-900 text-white'
                      : 'text-gray-300 hover:bg-gray-700 hover:text-white'
                    }`}
                >
                  <Icon className="h-5 w-5 mr-0 md:mr-2" />
                  <span className="hidden md:inline">{label}</span>
                </Link>
              );
            })}
          </div>
        </div>
      </div>
    </nav>
  );
}
EOF_SRC_COMPONENTS_NAVBAR_TSX
echo "Created src/components/Navbar.tsx"

# src/components/PeopleTable.tsx
cat << 'EOF_SRC_COMPONENTS_PEOPLE_TABLE_TSX' > src/components/PeopleTable.tsx
'use client';
import Link from 'next/link';
import { Person } from '@/types';
import { Button } from '@/components/ui/button';
import { TrashIcon, PencilSquareIcon } from '@heroicons/react/24/outline'; // Using outline for action icons

interface PeopleTableProps {
  people: Person[];
  onDelete: (id: string) => Promise<void>;
}

export default function PeopleTable({ people, onDelete }: PeopleTableProps) {
  if (!people || people.length === 0) {
    return null; // Handled by parent component's "No people found" message
  }

  return (
    <div className="overflow-x-auto shadow-md rounded-lg border border-gray-200">
      <table className="min-w-full divide-y divide-gray-200 bg-white">
        <thead className="bg-gray-50">
          <tr>
            <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Name</th>
            <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Email</th>
            <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Company</th>
            <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Birth Date</th>
            <th scope="col" className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
          </tr>
        </thead>
        <tbody className="bg-white divide-y divide-gray-200">
          {people.map((person) => (
            <tr key={person.id} className="hover:bg-gray-50 transition-colors">
              <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">{person.name}</td>
              <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{person.email}</td>
              <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                {person.company ? (
                  <Link href={\`/companies/\${person.company.id}/edit\` } className="text-blue-600 hover:underline">
                    {person.company.name}
                  </Link>
                ) : (
                  <span className="text-gray-400">N/A</span>
                )}
              </td>
              <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                {person.birthDate ? new Date(person.birthDate).toLocaleDateString() : <span className="text-gray-400">N/A</span>}
              </td>
              <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium space-x-2">
                <Link href={\`/people/\${person.id}/edit\`} passHref>
                  <Button variant="outline" size="sm" className="text-blue-600 border-blue-500 hover:bg-blue-50">
                    <PencilSquareIcon className="h-4 w-4" />
                    <span className="sr-only">Edit</span>
                  </Button>
                </Link>
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => onDelete(person.id)}
                  className="text-red-600 border-red-500 hover:bg-red-50"
                >
                  <TrashIcon className="h-4 w-4" />
                   <span className="sr-only">Delete</span>
                </Button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
EOF_SRC_COMPONENTS_PEOPLE_TABLE_TSX
echo "Created src/components/PeopleTable.tsx"

# src/components/PersonForm.tsx
cat << 'EOF_SRC_COMPONENTS_PERSON_FORM_TSX' > src/components/PersonForm.tsx
'use client';
import { useForm, SubmitHandler, Controller, useFieldArray } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Button } from '@/components/ui/button';
import { Textarea } from '@/components/ui/textarea'; // Assuming you have this
import { Person, Company, IPersonAddress } from '@/types';
import { useEffect, useState } from 'react';
import { PlusIcon, TrashIcon } from '@heroicons/react/24/outline';

const API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL || '/api';

const addressSchema = z.object({
  street: z.string().min(1, 'Street is required').max(100),
  city: z.string().min(1, 'City is required').max(50),
  state: z.string().min(1, 'State is required').max(50),
  postalCode: z.string().min(1, 'Postal Code is required').max(20),
  country: z.string().min(1, 'Country is required').max(50),
}).partial().refine(data => { // Make address optional if all fields are empty
    return Object.values(data).some(val => val && val.trim() !== '');
}, {
    message: "Address requires at least one field if provided.",
    path: [], // General path for the object
}).or(z.undefined());


const personFormSchema = z.object({
  name: z.string().min(2, 'Name must be at least 2 characters').max(100),
  email: z.string().email('Invalid email address').max(100),
  birthDate: z.string().optional().refine(val => !val || !isNaN(Date.parse(val)), {
    message: "Invalid date format. Use YYYY-MM-DD.",
  }),
  companyId: z.string().optional().nullable(),
  phoneNumbers: z.array(z.string().min(5, "Phone number seems too short").max(20).optional()).optional(),
  address: addressSchema,
});

export type PersonFormData = z.infer<typeof personFormSchema>;

interface PersonFormProps {
  onSubmit: SubmitHandler<PersonFormData>;
  initialData?: Partial<Person>; // Making it partial for flexibility
  isSubmitting?: boolean;
}

export default function PersonForm({ onSubmit, initialData, isSubmitting }: PersonFormProps) {
  const [companies, setCompanies] = useState<Company[]>([]);
  const [showAddress, setShowAddress] = useState(!!initialData?.address);

  const { control, register, handleSubmit, formState: { errors }, reset, watch, setValue } = useForm<PersonFormData>({
    resolver: zodResolver(personFormSchema),
    defaultValues: {
      name: initialData?.name || '',
      email: initialData?.email || '',
      birthDate: initialData?.birthDate ? new Date(initialData.birthDate).toISOString().split('T')[0] : '',
      companyId: initialData?.companyId || null, // Ensure null for 'No Company'
      phoneNumbers: initialData?.phoneNumbers || [''],
      address: initialData?.address || { street: '', city: '', state: '', postalCode: '', country: '' },
    },
  });

  const { fields, append, remove } = useFieldArray({
    control,
    name: "phoneNumbers"
  });

  useEffect(() => {
    // Fetch companies for dropdown
    const fetchCompanies = async () => {
      try {
        const response = await fetch(\`\${API_BASE_URL}/companies?limit=1000\`); // Get all companies
        const result = await response.json();
        if (result.success) {
          setCompanies(result.data);
        }
      } catch (error) {
        console.error("Failed to fetch companies", error);
      }
    };
    fetchCompanies();
  }, []);

  useEffect(() => {
    if (initialData) {
      reset({
        name: initialData.name || '',
        email: initialData.email || '',
        birthDate: initialData.birthDate ? new Date(initialData.birthDate).toISOString().split('T')[0] : '',
        companyId: initialData.companyId || null,
        phoneNumbers: initialData.phoneNumbers?.length ? initialData.phoneNumbers : [''],
        address: initialData.address || { street: '', city: '', state: '', postalCode: '', country: '' },
      });
      setShowAddress(!!initialData.address && Object.values(initialData.address).some(v => v));
    }
  }, [initialData, reset]);
  
  const watchedAddress = watch("address");
  useEffect(() => {
    if (watchedAddress && Object.values(watchedAddress).some(val => val && String(val).trim() !== '')) {
        setShowAddress(true);
    }
  }, [watchedAddress]);


  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
      <div>
        <Label htmlFor="name">Full Name</Label>
        <Input id="name" {...register('name')} aria-invalid={errors.name ? "true" : "false"} />
        {errors.name && <p role="alert" className="text-red-500 text-sm mt-1">{errors.name.message}</p>}
      </div>

      <div>
        <Label htmlFor="email">Email Address</Label>
        <Input id="email" type="email" {...register('email')} aria-invalid={errors.email ? "true" : "false"} />
        {errors.email && <p role="alert" className="text-red-500 text-sm mt-1">{errors.email.message}</p>}
      </div>

      <div>
        <Label htmlFor="birthDate">Birth Date (YYYY-MM-DD)</Label>
        <Input id="birthDate" type="date" {...register('birthDate')} aria-invalid={errors.birthDate ? "true" : "false"} />
        {errors.birthDate && <p role="alert" className="text-red-500 text-sm mt-1">{errors.birthDate.message}</p>}
      </div>

      <div>
        <Label htmlFor="companyId">Company</Label>
        <select
          id="companyId"
          {...register('companyId')}
          className="block w-full h-10 rounded-md border border-gray-300 bg-white px-3 py-2 text-sm shadow-sm focus:border-blue-500 focus:outline-none focus:ring-blue-500 disabled:cursor-not-allowed disabled:opacity-50"
        >
          <option value="">-- No Company --</option>
          {companies.map(company => (
            <option key={company.id} value={company.id}>{company.name}</option>
          ))}
        </select>
        {errors.companyId && <p role="alert" className="text-red-500 text-sm mt-1">{errors.companyId.message}</p>}
      </div>

      <div>
        <Label>Phone Numbers</Label>
        {fields.map((field, index) => (
          <div key={field.id} className="flex items-center space-x-2 mb-2">
            <Input
              {...register(\`phoneNumbers.\${index}\`)}
              placeholder="e.g., +1-555-123-4567"
              className="flex-grow"
            />
            {fields.length > 1 && (
              <Button type="button" variant="ghost" size="sm" onClick={() => remove(index)} aria-label="Remove phone number">
                <TrashIcon className="h-5 w-5 text-red-500" />
              </Button>
            )}
          </div>
        ))}
        {errors.phoneNumbers && <p role="alert" className="text-red-500 text-sm mt-1">{errors.phoneNumbers.message || errors.phoneNumbers.root?.message}</p>}
         {errors.phoneNumbers?.map((err, index) => err && <p key={index} role="alert" className="text-red-500 text-sm mt-1">{err.message}</p>)}

        <Button type="button" variant="outline" size="sm" onClick={() => append('')} className="mt-1">
          <PlusIcon className="h-4 w-4 mr-1" /> Add Phone
        </Button>
      </div>

      <div className="space-y-1">
        {!showAddress ? (
            <Button type="button" variant="outline" onClick={() => setShowAddress(true)}>
                Add Address (Optional)
            </Button>
        ) : (
            <h3 className="text-lg font-medium text-gray-700 pt-2">Address (Optional)</h3>
        )}
      </div>

      {showAddress && (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 p-4 border rounded-md">
            <div>
                <Label htmlFor="address.street">Street</Label>
                <Input id="address.street" {...register('address.street')} />
                {errors.address?.street && <p role="alert" className="text-red-500 text-sm mt-1">{errors.address.street.message}</p>}
            </div>
            <div>
                <Label htmlFor="address.city">City</Label>
                <Input id="address.city" {...register('address.city')} />
                {errors.address?.city && <p role="alert" className="text-red-500 text-sm mt-1">{errors.address.city.message}</p>}
            </div>
            <div>
                <Label htmlFor="address.state">State / Province</Label>
                <Input id="address.state" {...register('address.state')} />
                {errors.address?.state && <p role="alert" className="text-red-500 text-sm mt-1">{errors.address.state.message}</p>}
            </div>
            <div>
                <Label htmlFor="address.postalCode">Postal Code</Label>
                <Input id="address.postalCode" {...register('address.postalCode')} />
                {errors.address?.postalCode && <p role="alert" className="text-red-500 text-sm mt-1">{errors.address.postalCode.message}</p>}
            </div>
            <div className="md:col-span-2">
                <Label htmlFor="address.country">Country</Label>
                <Input id="address.country" {...register('address.country')} />
                {errors.address?.country && <p role="alert" className="text-red-500 text-sm mt-1">{errors.address.country.message}</p>}
            </div>
             {errors.address && !errors.address.street && !errors.address.city && !errors.address.state && !errors.address.postalCode && !errors.address.country && errors.address.message && (
                <p role="alert" className="text-red-500 text-sm mt-1 md:col-span-2">{errors.address.message}</p>
            )}
            <Button type="button" variant="ghost" size="sm" className="md:col-span-2 justify-self-start mt-2" onClick={() => {
                setValue('address', { street: '', city: '', state: '', postalCode: '', country: '' });
                setShowAddress(false);
            }}>
                Clear Address
            </Button>
        </div>
      )}


      <Button type="submit" disabled={isSubmitting} className="w-full sm:w-auto">
        {isSubmitting ? (
            <div className="flex items-center">
                <svg className="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                    <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                    <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                </svg>
                Submitting...
            </div>
        ) : (initialData?.id ? 'Save Changes' : 'Create Person')}
      </Button>
    </form>
  );
}
EOF_SRC_COMPONENTS_PERSON_FORM_TSX
echo "Created src/components/PersonForm.tsx"

# src/components/CompaniesTable.tsx
cat << 'EOF_SRC_COMPONENTS_COMPANIES_TABLE_TSX' > src/components/CompaniesTable.tsx
'use client';
import Link from 'next/link';
import { Company } from '@/types';
import { Button } from '@/components/ui/button';
import { TrashIcon, PencilSquareIcon } from '@heroicons/react/24/outline';

interface CompaniesTableProps {
  companies: Company[];
  onDelete: (id: string) => Promise<void>;
}

export default function CompaniesTable({ companies, onDelete }: CompaniesTableProps) {
   if (!companies || companies.length === 0) {
    return null; // Handled by parent component
  }

  return (
    <div className="overflow-x-auto shadow-md rounded-lg border border-gray-200">
      <table className="min-w-full divide-y divide-gray-200 bg-white">
        <thead className="bg-gray-50">
          <tr>
            <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Name</th>
            <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Contact Email</th>
            <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Industry</th>
            <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Founded</th>
            <th scope="col" className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
          </tr>
        </thead>
        <tbody className="bg-white divide-y divide-gray-200">
          {companies.map((company) => (
            <tr key={company.id} className="hover:bg-gray-50 transition-colors">
              <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">{company.name}</td>
              <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{company.contactEmail}</td>
              <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{company.industry || <span className="text-gray-400">N/A</span>}</td>
              <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                {company.foundedDate ? new Date(company.foundedDate).toLocaleDateString() : <span className="text-gray-400">N/A</span>}
              </td>
              <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium space-x-2">
                <Link href={\`/companies/\${company.id}/edit\`} passHref>
                  <Button variant="outline" size="sm" className="text-blue-600 border-blue-500 hover:bg-blue-50">
                    <PencilSquareIcon className="h-4 w-4" />
                     <span className="sr-only">Edit</span>
                  </Button>
                </Link>
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => onDelete(company.id)}
                   className="text-red-600 border-red-500 hover:bg-red-50"
                >
                  <TrashIcon className="h-4 w-4" />
                   <span className="sr-only">Delete</span>
                </Button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
EOF_SRC_COMPONENTS_COMPANIES_TABLE_TSX
echo "Created src/components/CompaniesTable.tsx"

# src/components/CompanyForm.tsx
cat << 'EOF_SRC_COMPONENTS_COMPANY_FORM_TSX' > src/components/CompanyForm.tsx
'use client';
import { useForm, SubmitHandler } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Button } from '@/components/ui/button';
import { Company, ICompanyAddress } from '@/types'; // Assuming Company type is suitable for form
import { useEffect, useState } from 'react';

const addressSchema = z.object({
  street: z.string().min(1, 'Street is required').max(100),
  city: z.string().min(1, 'City is required').max(50),
  state: z.string().min(1, 'State is required').max(50),
  postalCode: z.string().min(1, 'Postal Code is required').max(20),
  country: z.string().min(1, 'Country is required').max(50),
}).partial().refine(data => { // Make address optional if all fields are empty
    return Object.values(data).some(val => val && val.trim() !== '');
}, {
    message: "Address requires at least one field if provided.",
    path: [], // General path for the object
}).or(z.undefined());


const companyFormSchema = z.object({
  name: z.string().min(2, 'Company name must be at least 2 characters').max(100),
  contactEmail: z.string().email('Invalid contact email address').max(100),
  industry: z.string().max(100).optional(),
  foundedDate: z.string().optional().refine(val => !val || !isNaN(Date.parse(val)), {
    message: "Invalid date format. Use YYYY-MM-DD.",
  }),
  website: z.string().url('Invalid URL format (e.g., http://example.com)').max(200).optional().or(z.literal('')),
  address: addressSchema,
});

export type CompanyFormData = z.infer<typeof companyFormSchema>;

interface CompanyFormProps {
  onSubmit: SubmitHandler<CompanyFormData>;
  initialData?: Partial<Company>;
  isSubmitting?: boolean;
}

export default function CompanyForm({ onSubmit, initialData, isSubmitting }: CompanyFormProps) {
  const [showAddress, setShowAddress] = useState(!!initialData?.address);

  const { register, handleSubmit, formState: { errors }, reset, watch, setValue } = useForm<CompanyFormData>({
    resolver: zodResolver(companyFormSchema),
    defaultValues: {
      name: initialData?.name || '',
      contactEmail: initialData?.contactEmail || '',
      industry: initialData?.industry || '',
      foundedDate: initialData?.foundedDate ? new Date(initialData.foundedDate).toISOString().split('T')[0] : '',
      website: initialData?.website || '',
      address: initialData?.address || { street: '', city: '', state: '', postalCode: '', country: '' },
    },
  });
  
  useEffect(() => {
    if (initialData) {
      reset({
        name: initialData.name || '',
        contactEmail: initialData.contactEmail || '',
        industry: initialData.industry || '',
        foundedDate: initialData.foundedDate ? new Date(initialData.foundedDate).toISOString().split('T')[0] : '',
        website: initialData.website || '',
        address: initialData.address || { street: '', city: '', state: '', postalCode: '', country: '' },
      });
      setShowAddress(!!initialData.address && Object.values(initialData.address).some(v => v));
    }
  }, [initialData, reset]);

  const watchedAddress = watch("address");
  useEffect(() => {
    if (watchedAddress && Object.values(watchedAddress).some(val => val && String(val).trim() !== '')) {
        setShowAddress(true);
    }
  }, [watchedAddress]);


  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
      <div>
        <Label htmlFor="name">Company Name</Label>
        <Input id="name" {...register('name')} aria-invalid={errors.name ? "true" : "false"} />
        {errors.name && <p role="alert" className="text-red-500 text-sm mt-1">{errors.name.message}</p>}
      </div>

      <div>
        <Label htmlFor="contactEmail">Contact Email</Label>
        <Input id="contactEmail" type="email" {...register('contactEmail')} aria-invalid={errors.contactEmail ? "true" : "false"} />
        {errors.contactEmail && <p role="alert" className="text-red-500 text-sm mt-1">{errors.contactEmail.message}</p>}
      </div>

      <div>
        <Label htmlFor="industry">Industry (Optional)</Label>
        <Input id="industry" {...register('industry')} />
        {errors.industry && <p role="alert" className="text-red-500 text-sm mt-1">{errors.industry.message}</p>}
      </div>

      <div>
        <Label htmlFor="foundedDate">Founded Date (YYYY-MM-DD, Optional)</Label>
        <Input id="foundedDate" type="date" {...register('foundedDate')} aria-invalid={errors.foundedDate ? "true" : "false"} />
        {errors.foundedDate && <p role="alert" className="text-red-500 text-sm mt-1">{errors.foundedDate.message}</p>}
      </div>

      <div>
        <Label htmlFor="website">Website (Optional)</Label>
        <Input id="website" type="url" {...register('website')} placeholder="https://example.com" />
        {errors.website && <p role="alert" className="text-red-500 text-sm mt-1">{errors.website.message}</p>}
      </div>

      <div className="space-y-1">
        {!showAddress ? (
            <Button type="button" variant="outline" onClick={() => setShowAddress(true)}>
                Add Address (Optional)
            </Button>
        ) : (
             <h3 className="text-lg font-medium text-gray-700 pt-2">Address (Optional)</h3>
        )}
      </div>

      {showAddress && (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 p-4 border rounded-md">
            <div>
                <Label htmlFor="address.street">Street</Label>
                <Input id="address.street" {...register('address.street')} />
                {errors.address?.street && <p role="alert" className="text-red-500 text-sm mt-1">{errors.address.street.message}</p>}
            </div>
            <div>
                <Label htmlFor="address.city">City</Label>
                <Input id="address.city" {...register('address.city')} />
                {errors.address?.city && <p role="alert" className="text-red-500 text-sm mt-1">{errors.address.city.message}</p>}
            </div>
            <div>
                <Label htmlFor="address.state">State / Province</Label>
                <Input id="address.state" {...register('address.state')} />
                {errors.address?.state && <p role="alert" className="text-red-500 text-sm mt-1">{errors.address.state.message}</p>}
            </div>
            <div>
                <Label htmlFor="address.postalCode">Postal Code</Label>
                <Input id="address.postalCode" {...register('address.postalCode')} />
                {errors.address?.postalCode && <p role="alert" className="text-red-500 text-sm mt-1">{errors.address.postalCode.message}</p>}
            </div>
            <div className="md:col-span-2">
                <Label htmlFor="address.country">Country</Label>
                <Input id="address.country" {...register('address.country')} />
                {errors.address?.country && <p role="alert" className="text-red-500 text-sm mt-1">{errors.address.country.message}</p>}
            </div>
            {errors.address && !errors.address.street && !errors.address.city && !errors.address.state && !errors.address.postalCode && !errors.address.country && errors.address.message && (
                <p role="alert" className="text-red-500 text-sm mt-1 md:col-span-2">{errors.address.message}</p>
            )}
             <Button type="button" variant="ghost" size="sm" className="md:col-span-2 justify-self-start mt-2" onClick={() => {
                setValue('address', { street: '', city: '', state: '', postalCode: '', country: '' });
                setShowAddress(false);
            }}>
                Clear Address
            </Button>
        </div>
      )}

      <Button type="submit" disabled={isSubmitting} className="w-full sm:w-auto">
         {isSubmitting ? (
            <div className="flex items-center">
                <svg className="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                    <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                    <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                </svg>
                Submitting...
            </div>
        ) : (initialData?.id ? 'Save Changes' : 'Create Company')}
      </Button>
    </form>
  );
}
EOF_SRC_COMPONENTS_COMPANY_FORM_TSX
echo "Created src/components/CompanyForm.tsx"


# --- Lib ---
# src/lib/mongodb.ts
cat << 'EOF_SRC_LIB_MONGODB_TS' > src/lib/mongodb.ts
import mongoose from 'mongoose';

const MONGODB_URI = process.env.MONGODB_URI;

if (!MONGODB_URI) {
  throw new Error('Please define the MONGODB_URI environment variable inside .env or docker-compose.yml');
}

interface MongooseCache {
  conn: typeof mongoose | null;
  promise: Promise<typeof mongoose> | null;
}

// Extend global to include mongoose cache
// Use 'declare global' for global namespace augmentation
declare global {
  // eslint-disable-next-line no-var
  var mongoose_cache: MongooseCache;
}

let cached = global.mongoose_cache;

if (!cached) {
  cached = global.mongoose_cache = { conn: null, promise: null };
}

async function dbConnect(): Promise<typeof mongoose> {
  if (cached.conn) {
    // console.log("Using cached MongoDB connection.");
    return cached.conn;
  }

  if (!cached.promise) {
    const opts = {
      bufferCommands: false, // Disable mongoose buffering (good practice)
      // replicaSet: 'rs0', // Specify replica set if connecting to one directly outside docker-compose networking
    };
    console.log("Attempting new MongoDB connection...");
    cached.promise = mongoose.connect(MONGODB_URI, opts)
      .then((mongooseInstance) => {
        console.log("MongoDB connected successfully.");
        // Initialize models by importing them here if they are not automatically.
        // This is often needed if change streams are set up before any API route using the model is hit.
        import('@/models/Person');
        import('@/models/Company');
        return mongooseInstance;
      })
      .catch(err => {
        console.error("MongoDB connection error:", err);
        cached.promise = null; // Reset promise on error so retry can happen
        throw err;
      });
  }
  try {
    cached.conn = await cached.promise;
  } catch (e) {
    cached.promise = null; // Ensure promise is nulled if connection fails
    throw e;
  }

  return cached.conn;
}

export default dbConnect;
EOF_SRC_LIB_MONGODB_TS
echo "Created src/lib/mongodb.ts"

# src/lib/redis.ts
cat << 'EOF_SRC_LIB_REDIS_TS' > src/lib/redis.ts
import Redis, { RedisOptions } from 'ioredis';

const REDIS_HOST = process.env.REDIS_HOST || 'localhost';
const REDIS_PORT = parseInt(process.env.REDIS_PORT || '6379', 10);

const redisOptions: RedisOptions = {
  host: REDIS_HOST,
  port: REDIS_PORT,
  maxRetriesPerRequest: 3, // Retry a few times for commands
  enableReadyCheck: true, // Default is true, ensure it checks before operations
  retryStrategy: (times) => {
    // Exponential backoff for reconnections
    const delay = Math.min(times * 50, 2000); // Max 2 seconds
    console.warn(`Redis: Retrying connection (attempt ${times}), delay ${delay}ms`);
    return delay;
  },
  // For long-running consumers, you might want to adjust keepAlive
  // keepAlive: 12000, // Send PING every 12 seconds
};

// Singleton instances
let baseClient: Redis | null = null;
let publisherClient: Redis | null = null;
let consumerClient: Redis | null = null;

function createClient(role: string): Redis {
    console.log(`Redis: Creating new ${role} client to ${REDIS_HOST}:${REDIS_PORT}`);
    const client = new Redis(redisOptions);

    client.on('connect', () => console.log(`Redis ${role} Client: Connected to ${REDIS_HOST}:${REDIS_PORT}`));
    client.on('ready', () => console.log(`Redis ${role} Client: Ready`));
    client.on('error', (err) => console.error(`Redis ${role} Client Error:`, err.message, err.stack));
    client.on('close', () => console.log(`Redis ${role} Client: Connection closed`));
    client.on('reconnecting', () => console.log(`Redis ${role} Client: Reconnecting...`));
    client.on('end', () => console.log(`Redis ${role} Client: Connection ended`));
    
    return client;
}


export function getRedisInstance(): Redis {
  if (!baseClient || !baseClient.isOpen) { // isOpen check for ioredis v5+
    if(baseClient && !baseClient.isOpen) baseClient.disconnect(); // Clean up old one if closed
    baseClient = createClient('Base');
  }
  return baseClient;
}

export function getRedisPublisher(): Redis {
  if (!publisherClient || !publisherClient.isOpen) {
    if(publisherClient && !publisherClient.isOpen) publisherClient.disconnect();
    publisherClient = createClient('Publisher');
  }
  return publisherClient;
}

export function getRedisConsumer(): Redis {
   if (!consumerClient || !consumerClient.isOpen) {
    if(consumerClient && !consumerClient.isOpen) consumerClient.disconnect();
    // For consumers, sometimes a dedicated connection with different options might be needed
    // e.g., longer timeouts for blocking reads. For this app, same options are fine.
    consumerClient = createClient('Consumer');
  }
  return consumerClient;
}


// Graceful shutdown for standalone scripts or server termination
// In Next.js, this is harder to manage perfectly due to its lifecycle.
// This is more for if these were run as separate Node.js processes.
let shuttingDown = false;
async function gracefulShutdown(signal: string) {
  if (shuttingDown) return;
  shuttingDown = true;
  console.log(`\nReceived ${signal}. Closing Redis connections...`);
  try {
    if (baseClient && baseClient.isOpen) await baseClient.quit();
    if (publisherClient && publisherClient.isOpen) await publisherClient.quit();
    if (consumerClient && consumerClient.isOpen) await consumerClient.quit();
    console.log('All Redis clients disconnected gracefully.');
  } catch (err) {
    console.error('Error during Redis graceful shutdown:', err);
  } finally {
    process.exit(0);
  }
}

// Only register shutdown hooks if not in a Next.js specific server context
// or if explicitly meant to be a long-running script.
// For Next.js apps, the server handles process termination.
if (process.env.INITIALIZE_BACKGROUND_SERVICES === 'true' && typeof process.env.NEXT_RUNTIME === 'undefined') {
    process.on('SIGINT', () => gracefulShutdown('SIGINT'));
    process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
}
EOF_SRC_LIB_REDIS_TS
echo "Created src/lib/redis.ts"

# src/lib/utils.ts
cat << 'EOF_SRC_LIB_UTILS_TS' > src/lib/utils.ts
import { type ClassValue, clsx } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

// Add other utility functions as needed
export function formatDate(dateString?: string | Date): string {
  if (!dateString) return 'N/A';
  try {
    return new Date(dateString).toLocaleDateString(undefined, {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
    });
  } catch (e) {
    return 'Invalid Date';
  }
}

export function formatDateTime(dateString?: string | Date): string {
  if (!dateString) return 'N/A';
   try {
    return new Date(dateString).toLocaleString(undefined, {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  } catch (e) {
    return 'Invalid Date/Time';
  }
}
EOF_SRC_LIB_UTILS_TS
echo "Created src/lib/utils.ts"

# src/lib/actions.ts (Placeholder, can be used for Server Actions)
cat << 'EOF_SRC_LIB_ACTIONS_TS' > src/lib/actions.ts
'use server';

// This file is a placeholder for Next.js Server Actions.
// You can define server-side functions here that can be called directly from client components.
// Example:
/*
import { revalidatePath } from 'next/cache';

export async function myAction(formData: FormData) {
  // ... perform database operations or other server-side logic
  console.log(formData.get('name'));
  revalidatePath('/some-path'); // Revalidate cache for a specific path
  return { success: true, message: 'Action completed!' };
}
*/

export async function placeholderAction() {
  console.log("Placeholder server action executed.");
  return { message: "This is a placeholder server action." };
}
EOF_SRC_LIB_ACTIONS_TS
echo "Created src/lib/actions.ts"


# --- Models ---
# src/models/Company.ts
cat << 'EOF_SRC_MODELS_COMPANY_TS' > src/models/Company.ts
import mongoose, { Document, Model, Schema, Types } from 'mongoose';

export interface ICompanyAddress {
  street: string;
  city: string;
  state: string;
  postalCode: string;
  country: string;
}

// Interface for the document (excluding virtuals, methods, etc.)
export interface ICompany extends Document {
  _id: Types.ObjectId; // Explicitly define _id
  name: string;
  industry?: string;
  foundedDate?: Date;
  address?: ICompanyAddress;
  contactEmail: string;
  website?: string;
  createdAt: Date;
  updatedAt: Date;
}

const CompanyAddressSchema = new Schema<ICompanyAddress>({
  street: { type: String, required: true, trim: true },
  city: { type: String, required: true, trim: true },
  state: { type: String, required: true, trim: true },
  postalCode: { type: String, required: true, trim: true },
  country: { type: String, required: true, trim: true },
}, { _id: false });

const CompanySchema = new Schema<ICompany>({
  name: { type: String, required: true, unique: true, trim: true, index: true },
  industry: { type: String, trim: true },
  foundedDate: { type: Date },
  address: { type: CompanyAddressSchema, required: false },
  contactEmail: { 
    type: String, 
    required: true, 
    unique: true, 
    trim: true, 
    lowercase: true,
    match: [/.+\@.+\..+/, 'Please fill a valid email address'] 
  },
  website: { type: String, trim: true },
}, { 
  timestamps: true, // Adds createdAt and updatedAt
  toJSON: { 
    virtuals: true, // Ensure virtuals are included
    transform: (doc, ret) => {
      ret.id = ret._id.toString(); // Convert _id to id string
      delete ret._id;
      delete ret.__v;
    }
  },
  toObject: {
    virtuals: true,
    transform: (doc, ret) => {
      ret.id = ret._id.toString();
      delete ret._id;
      delete ret.__v;
    }
  }
});

// Add a virtual 'id' field that returns _id as a string (alternative to transform)
// CompanySchema.virtual('id').get(function() {
//   return this._id.toHexString();
// });


const Company: Model<ICompany> = mongoose.models.Company || mongoose.model<ICompany>('Company', CompanySchema);

export default Company;
EOF_SRC_MODELS_COMPANY_TS
echo "Created src/models/Company.ts"

# src/models/Person.ts
cat << 'EOF_SRC_MODELS_PERSON_TS' > src/models/Person.ts
import mongoose, { Document, Model, Schema, Types } from 'mongoose';
import { ICompany } from './Company'; // Import ICompany for typing the populated field

// Use ICompanyAddress from Company.ts if the structure is identical, or define a new one
export interface IPersonAddress {
  street: string;
  city: string;
  state: string;
  postalCode: string;
  country: string;
}

export interface IPerson extends Document {
  _id: Types.ObjectId; // Explicitly define _id
  name: string;
  email: string;
  birthDate?: Date;
  address?: IPersonAddress;
  phoneNumbers?: string[];
  companyId?: Types.ObjectId | ICompany; // Can be ObjectId or populated ICompany object
  createdAt: Date;
  updatedAt: Date;
}

const PersonAddressSchema = new Schema<IPersonAddress>({
  street: { type: String, required: true, trim: true },
  city: { type: String, required: true, trim: true },
  state: { type: String, required: true, trim: true },
  postalCode: { type: String, required: true, trim: true },
  country: { type: String, required: true, trim: true },
}, { _id: false });

const PersonSchema = new Schema<IPerson>({
  name: { type: String, required: true, trim: true, index: true },
  email: { 
    type: String, 
    required: true, 
    unique: true, 
    trim: true, 
    lowercase: true,
    match: [/.+\@.+\..+/, 'Please fill a valid email address'] 
  },
  birthDate: { type: Date },
  address: { type: PersonAddressSchema, required: false },
  phoneNumbers: [{ type: String, trim: true }],
  companyId: { type: Schema.Types.ObjectId, ref: 'Company', required: false }, // Optional link
}, { 
  timestamps: true,
  toJSON: { 
    virtuals: true,
    transform: (doc, ret) => {
      ret.id = ret._id.toString();
      if (ret.companyId && typeof ret.companyId === 'object' && ret.companyId._id) {
        // If companyId is populated, ensure its id is also a string
        // And structure it as `company: { id: ..., name: ... }` if that's what frontend expects
        // This part needs to align with how you handle population in API routes.
        // For simplicity here, we'll just ensure companyId string if it's an ObjectId
        if (!(ret.companyId instanceof Types.ObjectId)) { // if populated
            ret.company = {id: ret.companyId._id.toString(), name: ret.companyId.name };
            ret.companyId = ret.companyId._id.toString();
        } else {
             ret.companyId = ret.companyId.toString();
        }

      } else if (ret.companyId instanceof Types.ObjectId) {
        ret.companyId = ret.companyId.toString();
      }
      delete ret._id;
      delete ret.__v;
    }
  },
  toObject: { // Similar transformation for toObject if needed
    virtuals: true,
    transform: (doc, ret) => {
      ret.id = ret._id.toString();
      if (ret.companyId && typeof ret.companyId === 'object' && ret.companyId._id) {
         if (!(ret.companyId instanceof Types.ObjectId)) {
            ret.company = {id: ret.companyId._id.toString(), name: ret.companyId.name };
            ret.companyId = ret.companyId._id.toString();
        } else {
             ret.companyId = ret.companyId.toString();
        }
      } else if (ret.companyId instanceof Types.ObjectId) {
        ret.companyId = ret.companyId.toString();
      }
      delete ret._id;
      delete ret.__v;
    }
  }
});


const Person: Model<IPerson> = mongoose.models.Person || mongoose.model<IPerson>('Person', PersonSchema);

export default Person;
EOF_SRC_MODELS_PERSON_TS
echo "Created src/models/Person.ts"

# --- Services ---
# src/services/cdcService.ts
cat << 'EOF_SRC_SERVICES_CDCSERVICE_TS' > src/services/cdcService.ts
import mongoose, { ChangeStreamDocument, ChangeStreamOptions } from 'mongoose';
import { getRedisPublisher } from '@/lib/redis';
import Person from '@/models/Person';
import Company from '@/models/Company';
import dbConnect from '@/lib/mongodb';

const REDIS_CHANGES_STREAM_KEY = 'la:people:changes';
let changeStreamsInitialized = false; // Plural, as we have multiple
const serviceName = "CDCService";

async function publishChangeEvent(
  operationType: string,
  collectionName: string,
  documentId: string | mongoose.Types.ObjectId,
  fullDocument?: any,
  updateDescription?: any
) {
  const redis = getRedisPublisher();
  if (!redis || !redis.isOpen) { // isOpen for ioredis v5+
    console.error(\`[\${serviceName}] Redis publisher not available. Skipping event publication.\`);
    return;
  }

  const eventData: Record<string, string> = { // All XADD values must be strings
    operationType,
    collectionName,
    documentId: documentId.toString(),
    timestamp: new Date().toISOString(),
  };

  if (fullDocument) {
    // Stringify complex objects
    // Be mindful of sensitive data before logging or streaming fullDocument
    const { _id, __v, ...docData } = fullDocument; // Exclude _id and __v if already covered or not needed
    eventData.fullDocument = JSON.stringify(docData);
  }
  if (updateDescription) {
    eventData.updatedFields = JSON.stringify(updateDescription.updatedFields || {});
    eventData.removedFields = JSON.stringify(updateDescription.removedFields || []);
  }


  try {
    // XADD streamName * field1 value1 field2 value2 ...
    const messageArgs: string[] = [];
    for (const [key, value] of Object.entries(eventData)) {
        messageArgs.push(key, value); // Value is already string or stringified
    }

    await redis.xadd(REDIS_CHANGES_STREAM_KEY, '*', ...messageArgs);
    console.log(\`[\${serviceName}] Event published to \${REDIS_CHANGES_STREAM_KEY}: \${operationType} on \${collectionName} (\${documentId})\`);
  } catch (error) {
    console.error(\`[\${serviceName}] Error publishing CDC event to Redis for \${collectionName}:\`, error);
  }
}

export async function initializeChangeStreams() {
  if (changeStreamsInitialized) {
    console.log(\`[\${serviceName}] Change streams already initialized.\`);
    return;
  }
  
  // Guard against running in non-server environments or when disabled
  if (typeof window !== 'undefined' || process.env.INITIALIZE_BACKGROUND_SERVICES !== 'true') {
    console.log(\`[\${serviceName}] Skipping change stream initialization (not in correct environment or disabled).\`);
    return;
  }

  console.log(\`[\${serviceName}] Attempting to initialize MongoDB Change Streams...\`);

  try {
    await dbConnect(); // Ensure DB is connected
    const redis = getRedisPublisher(); // Ensure Redis publisher is connected and ready
    if (!redis || !redis.isOpen) { //isOpen is for ioredis v5+
      console.error(\`[\${serviceName}] Redis publisher not ready. Aborting change stream initialization.\`);
      // Consider retrying or a more robust ready check for Redis
      return; 
    }
  } catch (err) {
    console.error(\`[\${serviceName}] Prerequisite check failed (DB or Redis connection): \`, err);
    return;
  }


  const collectionsToWatch = [
    { model: Person, name: 'people' },
    { model: Company, name: 'companies' },
  ];

  const changeStreamOptions: ChangeStreamOptions = {
    fullDocument: 'updateLookup', // Gets the full document on updates
    fullDocumentBeforeChange: 'off', // 'whenAvailable' or 'required' if you need pre-image
  };

  collectionsToWatch.forEach(collInfo => {
    console.log(\`[\${serviceName}] Setting up change stream for collection: \${collInfo.name}\`);
    const changeStream = collInfo.model.watch([], changeStreamOptions);

    changeStream.on('change', (change: ChangeStreamDocument<any>) => {
      // console.log(\`[\${serviceName}] Change detected in '\${collInfo.name}':\`, change.operationType);
      
      let documentId: string | mongoose.Types.ObjectId;
      let docData: any;
      let updateDesc: any;

      switch (change.operationType) {
        case 'insert':
          documentId = change.fullDocument._id;
          docData = change.fullDocument;
          break;
        case 'update':
          documentId = change.documentKey._id;
          docData = change.fullDocument; // Contains the document *after* the update due to 'updateLookup'
          updateDesc = change.updateDescription;
          break;
        case 'replace': // e.g. findOneAndReplace
            documentId = change.documentKey._id;
            docData = change.fullDocument;
            break;
        case 'delete':
          documentId = change.documentKey._id;
          // For delete, fullDocument is not available in the change event itself.
          // The 'documentKey' (_id) is what's important.
          break;
        default:
          console.log(\`[\${serviceName}] Unhandled change type in '\${collInfo.name}':\`, change.operationType);
          return;
      }
      publishChangeEvent(change.operationType, collInfo.name, documentId, docData, updateDesc);
    });

    changeStream.on('error', (error) => {
      console.error(\`[\${serviceName}] Error in '\${collInfo.name}' change stream:\`, error);
      // Optional: Implement retry logic or attempt to re-establish the stream.
      // For now, we just log it. Mongoose might attempt to reconnect automatically.
      // If it's a "ResumableChangeStreamError", Mongoose usually handles it.
      // If it's "ChangeStream początkowa was killed", it means the cursor died, possibly due to inactivity or server issues.
      if (error.name === 'MongoNetworkError' || error.message.includes('timed out')) {
        console.warn(\`[\${serviceName}] Network error in change stream for \${collInfo.name}. Mongoose might attempt to reconnect.\`);
      } else if (error.code === 280 || error.codeName === 'ChangeStreamKilled') { // ChangeStreamKilled example
        console.warn(\`[\${serviceName}] Change stream for \${collInfo.name} was killed. Attempting to re-initialize might be needed if Mongoose doesn't recover.\`);
        // Consider a mechanism to re-initialize if persistent errors occur.
      }
    });
    
    changeStream.on('close', () => {
        console.log(\`[\${serviceName}] Change stream closed for \${collInfo.name}. This might be due to graceful shutdown or an unrecoverable error.\`);
    });
    
    console.log(\`[\${serviceName}] Change stream listener attached for \${collInfo.name}\`);
  });

  console.log(\`[\${serviceName}] MongoDB Change Streams initialization process completed.\`);
  changeStreamsInitialized = true;
}

// Optional: A function to close streams if needed, though Mongoose might handle this on connection.close()
export async function closeChangeStreams() {
    if (changeStreamsInitialized) {
        // Mongoose change streams are cursors. Closing the mongoose connection should ideally close them.
        // Or, store stream instances and call .close() on each.
        console.log("Closing change streams would typically involve closing Mongoose connection or specific stream instances.");
        changeStreamsInitialized = false;
    }
}
EOF_SRC_SERVICES_CDCSERVICE_TS
echo "Created src/services/cdcService.ts"

# src/services/redisConsumerService.ts
cat << 'EOF_SRC_SERVICES_REDISCONSUMERSERVICE_TS' > src/services/redisConsumerService.ts
import { getRedisConsumer, getRedisInstance } from '@/lib/redis'; // Using getRedisInstance for publishing
import Redis from 'ioredis'; // For type

const SYNC_REQUEST_STREAM_KEY = 'la:people:sync:request';
const CONSUMER_GROUP_NAME = 'app-default-group'; // More descriptive group name
const CONSUMER_NAME_PREFIX = 'peopleapp-consumer'; // Prefix for consumer instances

let consumerInitialized = false;
let isShuttingDown = false; // Flag to manage graceful shutdown
const serviceName = "RedisConsumerService";

// Function to create the consumer group (idempotent)
async function createConsumerGroup(redis: Redis) {
  try {
    // XGROUP CREATE stream_key group_name $ MKSTREAM
    // MKSTREAM creates the stream if it doesn't exist
    // '$' means only new messages arriving after group creation. Use '0' for all history (if stream already exists).
    await redis.xgroup('CREATE', SYNC_REQUEST_STREAM_KEY, CONSUMER_GROUP_NAME, '$', 'MKSTREAM');
    console.log(\`[\${serviceName}] Consumer group '\${CONSUMER_GROUP_NAME}' created or already exists for stream '\${SYNC_REQUEST_STREAM_KEY}'.\`);
  } catch (error: any) {
    if (error.message.includes('BUSYGROUP')) {
      console.log(\`[\${serviceName}] Consumer group '\${CONSUMER_GROUP_NAME}' already exists for stream '\${SYNC_REQUEST_STREAM_KEY}'.\`);
    } else {
      console.error(\`[\${serviceName}] Error creating consumer group '\${CONSUMER_GROUP_NAME}':\`, error);
      // Depending on the error, you might want to retry or throw
      // For now, we log and continue, assuming BUSYGROUP is the common "ignorable" error.
    }
  }
}

async function processMessage(messageId: string, messageData: string[], consumerName: string) {
  console.log(\`[\${consumerName}] Processing message \${messageId} from \${SYNC_REQUEST_STREAM_KEY}:\`);
  const parsedData: Record<string, string> = {};
  for (let i = 0; i < messageData.length; i += 2) {
    parsedData[messageData[i]] = messageData[i + 1];
  }
  console.log(\`[\${consumerName}] Parsed Data:\`, parsedData);

  // TODO: Implement your logic to process the event and write to other queues
  // This is where you'd dispatch tasks based on `parsedData.type` or other fields.
  // Example: Forwarding to another stream/queue based on type
  const eventType = parsedData.type || 'unknown_event';
  const targetQueue = \`downstream:service:\${eventType.toLowerCase().replace(/_ ज़्यादा/g, ':')}\`; // Example: la:sync:user -> downstream:service:user
  
  try {
    const publisher = getRedisInstance(); // Use a general instance for publishing to other queues
    if (!publisher || !publisher.isOpen) {
        console.error(\`[\${consumerName}] Redis publisher not available for forwarding message \${messageId}\`);
        throw new Error("Redis publisher unavailable"); // This will cause message to not be ACKed and retried later
    }
    const forwardPayload = { ...parsedData, processedBy: consumerName, originalMessageId: messageId, processedAt: new Date().toISOString() };
    const messageArgs: string[] = [];
    for (const [key, value] of Object.entries(forwardPayload)) {
        messageArgs.push(key, String(value));
    }
    await publisher.xadd(targetQueue, '*', ...messageArgs);
    console.log(\`[\${consumerName}] Event \${messageId} forwarded to queue: \${targetQueue}\`);
  } catch(error) {
    console.error(\`[\${consumerName}] Failed to forward message \${messageId} to \${targetQueue}:\`, error);
    throw error; // Re-throw to prevent ACK if forwarding is critical
  }


  // Simulate processing time
  // await new Promise(resolve => setTimeout(resolve, Math.random() * 500 + 100)); 
  console.log(\`[\${consumerName}] Finished processing message \${messageId}\`);
}

async function consumeMessages() {
  const consumerName = \`\${CONSUMER_NAME_PREFIX}-\${process.pid}\`;
  let redis: Redis;

  try {
    redis = getRedisConsumer();
    if (!redis || !redis.isOpen) { //isOpen for ioredis v5+
      console.error(\`[\${serviceName}] Redis consumer client not ready. Aborting consumer loop for \${consumerName}.\`);
      return; // Exit if client not ready
    }
    await createConsumerGroup(redis);
  } catch (err) {
     console.error(\`[\${serviceName}] Failed prerequisite for consumer \${consumerName}:\`, err);
     return; // Exit if setup fails
  }


  console.log(\`[\${consumerName}] Starting to listen to stream '\${SYNC_REQUEST_STREAM_KEY}' in group '\${CONSUMER_GROUP_NAME}'...\`);

  while (!isShuttingDown) {
    try {
      // XREADGROUP GROUP group_name consumer_name [COUNT count] [BLOCK milliseconds] STREAMS key [key ...] id [id ...]
      // Using '>' to read new messages that arrive after joining the group.
      // BLOCK 0 means block indefinitely. A timeout (e.g., 5000ms) allows graceful shutdown and periodic checks.
      const response = await redis.xreadgroup(
        'GROUP', CONSUMER_GROUP_NAME, consumerName,
        'COUNT', '10',     // Read up to 10 messages at a time
        'BLOCK', '5000',   // Block for 5 seconds if no messages (adjust as needed)
        'STREAMS', SYNC_REQUEST_STREAM_KEY, '>' // '>' means only new messages for this consumer
      );

      if (isShuttingDown) break; // Check again after potential block

      if (response) {
        // response is an array like: [ [streamName, [ [messageId1, fields1], [messageId2, fields2] ]] ]
        for (const streamMessages of response) {
          // const streamName = streamMessages[0]; // Should be SYNC_REQUEST_STREAM_KEY
          const messages = streamMessages[1] as [string, string[]][]; // Type assertion

          if (messages.length === 0) continue;
          // console.log(\`[\${consumerName}] Received \${messages.length} messages from \${streamName}\`);

          const messageIdsToAck: string[] = [];
          for (const [messageId, messageData] of messages) {
            if (isShuttingDown) break; // Check before processing each message
            try {
              await processMessage(messageId, messageData, consumerName);
              messageIdsToAck.push(messageId);
            } catch (processingError) {
              console.error(\`[\${consumerName}] Error processing message \${messageId}, it will not be ACKed and may be redelivered:\`, processingError);
              // TODO: Implement dead-letter queue (DLQ) logic here if needed
              // e.g., XADD to a DLQ stream, then XACK the original message
            }
          }

          // Acknowledge messages that were successfully processed
          if (messageIdsToAck.length > 0) {
            try {
              await redis.xack(SYNC_REQUEST_STREAM_KEY, CONSUMER_GROUP_NAME, ...messageIdsToAck);
              // console.log(\`[\${consumerName}] Acknowledged \${messageIdsToAck.length} messages.\`);
            } catch (ackError) {
              console.error(\`[\${consumerName}] Error acknowledging messages:\`, ackError, { messageIdsToAck });
              // This is problematic as messages might be reprocessed. Monitor this.
            }
          }
        }
      } else {
        // No messages received, BLOCK timed out. Loop will continue.
        // console.log(\`[\${consumerName}] No new messages from '\${SYNC_REQUEST_STREAM_KEY}', waiting...\`);
      }
    } catch (error: any) {
      if (isShuttingDown) break; // Exit loop if shutting down during an error
      console.error(\`[\${consumerName}] Error reading from stream '\${SYNC_REQUEST_STREAM_KEY}':\`, error.message);
      // Handle specific errors, e.g., connection issues
      if (error.message.includes('NOGROUP')) {
        console.warn(\`[\${consumerName}] Group '\${CONSUMER_GROUP_NAME}' or stream '\${SYNC_REQUEST_STREAM_KEY}' may not exist. Attempting to recreate group...\`);
        await createConsumerGroup(redis); // Attempt to recreate
      }
      // Implement robust retry logic or error handling (e.g., delay before retrying)
      await new Promise(resolve => setTimeout(resolve, 5000)); // Wait 5s before retrying loop
    }
  }
  console.log(\`[\${consumerName}] Consumer loop for '\${SYNC_REQUEST_STREAM_KEY}' is shutting down.\`);
  // Optional: Unregister consumer from group if desired, though usually not necessary
  // await redis.xgroup('DELCONSUMER', SYNC_REQUEST_STREAM_KEY, CONSUMER_GROUP_NAME, consumerName);
}

export async function initializeRedisConsumer() {
  if (consumerInitialized) {
    console.log(\`[\${serviceName}] Redis Stream Consumer already initialized.\`);
    return;
  }
  if (typeof window !== 'undefined' || process.env.INITIALIZE_BACKGROUND_SERVICES !== 'true') {
    console.log(\`[\${serviceName}] Skipping Redis consumer initialization (not in correct environment or disabled).\`);
    return;
  }

  console.log(\`[\${serviceName}] Initializing Redis Stream Consumer...\`);
  consumerInitialized = true;
  isShuttingDown = false; // Reset shutdown flag

  // Start consuming in a non-blocking way
  consumeMessages().catch(err => {
    console.error(\`[\${serviceName}] Redis consumer loop exited with error:\`, err);
    consumerInitialized = false; // Allow re-initialization on next attempt if appropriate
    // Potentially restart or log critical failure
  });
}

export async function stopRedisConsumer() {
    if (consumerInitialized && !isShuttingDown) {
        console.log(\`[\${serviceName}] Attempting to stop Redis Stream Consumer gracefully...\`);
        isShuttingDown = true;
        // The consumer loop will check `isShuttingDown` and exit.
        // You might add a timeout here if needed, or rely on Redis client disconnect.
        // The actual Redis client disconnection is handled in lib/redis.ts gracefulShutdown
    }
}
EOF_SRC_SERVICES_REDISCONSUMERSERVICE_TS
echo "Created src/services/redisConsumerService.ts"


# --- Types ---
# src/types/index.ts
cat << 'EOF_SRC_TYPES_INDEX_TS' > src/types/index.ts
import { ICompany as MongoCompany, ICompanyAddress as MongoCompanyAddress } from '@/models/Company';
import { IPerson as MongoPerson, IPersonAddress as MongoPersonAddress } from '@/models/Person';

// Re-export MongoDB address types if they are suitable for frontend directly
export type ICompanyAddress = MongoCompanyAddress;
export type IPersonAddress = MongoPersonAddress;

// Frontend-friendly Company type
// Omits Mongoose-specific fields like __v, and ensures _id is 'id' as string
// Dates are kept as string to align with form inputs (type="date") and JSON transport
export interface Company extends Omit<MongoCompany, '_id' | 'createdAt' | 'updatedAt' | 'foundedDate' | 'address'> {
  id: string;
  foundedDate?: string; // Dates as string for form inputs (YYYY-MM-DD)
  address?: ICompanyAddress; // Keep address structure
  createdAt: string; // Dates as ISO strings from server
  updatedAt: string;
}

// Frontend-friendly Person type
export interface Person extends Omit<MongoPerson, '_id' | 'createdAt' | 'updatedAt' | 'birthDate' | 'companyId' | 'address'> {
  id: string;
  birthDate?: string; // Dates as string for form inputs (YYYY-MM-DD)
  companyId?: string | null; // ObjectId as string, or null if not set
  company?: { id: string; name: string }; // For populated company data
  address?: IPersonAddress; // Keep address structure
  phoneNumbers?: string[];
  createdAt: string; // Dates as ISO strings from server
  updatedAt: string;
}


export interface PaginatedResponse<T> {
  success: boolean;
  data: T[];
  pagination: {
    currentPage: number;
    totalPages: number;
    totalItems: number;
    itemsPerPage: number;
  };
  error?: string;
}

// Generic API response for single items or mutations
export interface ApiResponse<T = any> {
  success: boolean;
  data?: T;
  error?: string;
  issues?: { path: (string|number)[]; message: string }[]; // For Zod validation issues
}
EOF_SRC_TYPES_INDEX_TS
echo "Created src/types/index.ts"

echo ""
echo "---------------------------------------------------------------------"
echo "Project '$PROJECT_NAME' structure and files created successfully!"
echo "---------------------------------------------------------------------"
echo ""
echo "Next Steps:"
echo "1. Navigate into the project directory if you aren't already:"
echo "   cd $PROJECT_NAME"
echo ""
echo "2. Install dependencies:"
echo "   npm install"
echo "   (or 'pnpm install' or 'yarn install' if you prefer and adapt package.json/Dockerfile)"
echo ""
echo "3. (Optional but Recommended) Initialize Git repository:"
echo "   git init"
echo "   git add ."
echo "   git commit -m \"Initial project setup from script\""
echo ""
echo "4. Build and run the application using Docker Compose:"
echo "   docker-compose up --build -d"
echo "   (The first build might take some time. Add '-d' to run in detached mode.)"
echo ""
echo "5. Access the application in your browser:"
echo "   http://localhost:3000"
echo ""
echo "6. To view logs:"
echo "   docker-compose logs -f app"
echo "   docker-compose logs -f mongo"
echo "   docker-compose logs -f redis-integration-db"
echo ""
echo "7. To stop the application:"
echo "   docker-compose down"
echo ""
echo "Important Notes:"
echo "- The MongoDB service requires replica set initialization for Change Streams."
echo "  The 'mongo-init.js' script handles this on the first run of the 'mongo' container."
echo "  If you encounter issues with Change Streams, check the 'mongo' container logs."
echo "- Background services (CDC, Redis Consumer) are set to initialize based on"
echo "  'INITIALIZE_BACKGROUND_SERVICES=true' in '.env.local' and 'docker-compose.yml'."
echo "- This script provides a comprehensive starting point. You'll likely want to"
echo "  refine UI/UX, add more robust error handling, and expand features."
echo "---------------------------------------------------------------------"

exit 0
```

**How to use this script:**

1.  Save the entire block of code above into a file, for example, `create_full_app.sh`.
2.  Open your terminal or command prompt.
3.  Navigate to the directory where you want to create the `nextjs-mongo-redis-app` project (e.g., `cd ~/Projects`).
4.  Make the script executable: `chmod +x create_full_app.sh`.
5.  Run the script: `./create_full_app.sh`.
6.  The script will create the `nextjs-mongo-redis-app` directory, `cd` into it, and then create all the subdirectories and files with their respective content.
7.  Follow the "Next Steps" printed by the script at the end. Primarily:
    *   `cd nextjs-mongo-redis-app` (if not already in it from script execution)
    *   `npm install`
    *   `docker-compose up --build -d`

This script is quite substantial. Test it in a safe environment first. If you encounter any "command not found" for `cat` or `mkdir`, ensure you are in a bash-compatible environment (like Linux, macOS, or WSL on Windows).  

---  



