import { NextResponse } from "next/server";
import { db } from "@/db";
import { sql } from "drizzle-orm";

export async function GET() {
  try {
    // Readiness probe - checks if Next.js and database are ready
    // This checks database connectivity to ensure the app can serve traffic
    await db.execute(sql`SELECT 1`);

    return NextResponse.json({
      status: "ready",
      timestamp: new Date().toISOString(),
      database: "connected",
    });
  } catch (error) {
    // If database is not ready, return 503
    return NextResponse.json(
      {
        status: "not_ready",
        timestamp: new Date().toISOString(),
        database: "disconnected",
        error: error instanceof Error ? error.message : "Unknown error",
      },
      { status: 503 }
    );
  }
}

export async function HEAD() {
  try {
    // For HEAD requests, just check connectivity without body
    await db.execute(sql`SELECT 1`);
    return new NextResponse(null, { status: 200 });
  } catch (error) {
    return new NextResponse(null, { status: 503 });
  }
}
