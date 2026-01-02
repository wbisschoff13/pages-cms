import { NextResponse } from "next/server";

export async function GET() {
  // Liveness probe - returns 200 if Next.js is running
  // This should always return 200 if the application is alive
  return NextResponse.json({
    status: "alive",
    timestamp: new Date().toISOString(),
  });
}

export async function HEAD() {
  return new NextResponse(null, { status: 200 });
}
