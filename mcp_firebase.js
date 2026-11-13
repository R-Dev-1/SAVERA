const admin = require("firebase-admin");
const { getDatabase } = require("firebase-admin/database");
const { Server } = require("@modelcontextprotocol/sdk/server/index.js");
const { StdioServerTransport } = require("@modelcontextprotocol/sdk/server/stdio.js");
const { CallToolRequestSchema, ListToolsRequestSchema } = require("@modelcontextprotocol/sdk/types.js");

const serviceAccount = require("./serviceAccountKey.json");

const certCredential = (admin.credential && admin.credential.cert)
  ? admin.credential.cert(serviceAccount)
  : (admin.cert ? admin.cert(serviceAccount) : serviceAccount);

const app = admin.initializeApp({
  credential: certCredential,
  databaseURL: "https://teman-jalan-13983-default-rtdb.asia-southeast1.firebasedatabase.app"
});

const db = getDatabase ? getDatabase(app) : admin.database();

const server = new Server(
  { name: "savera-firebase-mcp", version: "1.0.0" },
  { capabilities: { tools: {} } }
);

server.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: [
      {
        name: "read_firebase",
        description: "Membaca data dari Firebase Realtime Database.",
        inputSchema: {
          type: "object",
          properties: { path: { type: "string" } },
          required: ["path"],
        },
      },
      {
        name: "write_firebase",
        description: "Menulis atau menimpa data ke Firebase Realtime Database.",
        inputSchema: {
          type: "object",
          properties: {
            path: { type: "string" },
            data: {},
          },
          required: ["path", "data"],
        },
      },
      {
        name: "update_firebase",
        description: "Memperbarui field tertentu tanpa menimpa node di Firebase Realtime Database.",
        inputSchema: {
          type: "object",
          properties: {
            path: { type: "string" },
            data: { type: "object" },
          },
          required: ["path", "data"],
        },
      },
      {
        name: "push_firebase",
        description: "Menambahkan child baru dengan ID unik otomatis ke Firebase Realtime Database.",
        inputSchema: {
          type: "object",
          properties: {
            path: { type: "string" },
            data: {},
          },
          required: ["path", "data"],
        },
      },
      {
        name: "delete_firebase",
        description: "Menghapus data atau node dari Firebase Realtime Database.",
        inputSchema: {
          type: "object",
          properties: {
            path: { type: "string" },
          },
          required: ["path"],
        },
      }
    ],
  };
});

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  try {
    const { name, arguments: args } = request.params;
    if (name === "read_firebase") {
      const snapshot = await db.ref(args.path).once("value");
      return { content: [{ type: "text", text: JSON.stringify(snapshot.val(), null, 2) }] };
    } else if (name === "write_firebase") {
      await db.ref(args.path).set(args.data);
      return { content: [{ type: "text", text: "Data berhasil ditulis ke " + args.path }] };
    } else if (name === "update_firebase") {
      await db.ref(args.path).update(args.data);
      return { content: [{ type: "text", text: "Data berhasil diperbarui di " + args.path }] };
    } else if (name === "push_firebase") {
      const newRef = await db.ref(args.path).push(args.data);
      return { content: [{ type: "text", text: "Data berhasil di-push ke " + args.path + " dengan key " + newRef.key }] };
    } else if (name === "delete_firebase") {
      await db.ref(args.path).remove();
      return { content: [{ type: "text", text: "Data berhasil dihapus dari " + args.path }] };
    }
    throw new Error("Tool tidak ditemukan: " + name);
  } catch (error) {
    return { content: [{ type: "text", text: "Error: " + error.message }] };
  }
});

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
}
main().catch(console.error);
