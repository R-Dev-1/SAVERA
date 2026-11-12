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
        description: "Menulis atau mengubah data ke Firebase Realtime Database.",
        inputSchema: {
          type: "object",
          properties: {
            path: { type: "string" },
            data: { type: "object" },
          },
          required: ["path", "data"],
        },
      }
    ],
  };
});

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  try {
    if (request.params.name === "read_firebase") {
      const snapshot = await db.ref(request.params.arguments.path).once("value");
      return { content: [{ type: "text", text: JSON.stringify(snapshot.val(), null, 2) }] };
    } else if (request.params.name === "write_firebase") {
      await db.ref(request.params.arguments.path).set(request.params.arguments.data);
      return { content: [{ type: "text", text: "Data berhasil ditulis ke " + request.params.arguments.path }] };
    }
    throw new Error("Tool tidak ditemukan");
  } catch (error) {
    return { content: [{ type: "text", text: "Error: " + error.message }] };
  }
});

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
}
main().catch(console.error);
