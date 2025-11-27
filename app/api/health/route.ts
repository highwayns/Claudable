/**
 * Health Check API Endpoint
 * Used by Docker health checks and monitoring systems
 */

import { NextResponse } from 'next/server';
import { prisma } from '@/lib/db/client';

export async function GET() {
  try {
    // Check database connectivity
    await prisma.$queryRaw`SELECT 1`;

    // Check if application is ready
    const status = {
      status: 'healthy',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      environment: process.env.NODE_ENV,
      database: 'connected',
    };

    return NextResponse.json(status, { status: 200 });
  } catch (error) {
    // Database or application error
    const errorStatus = {
      status: 'unhealthy',
      timestamp: new Date().toISOString(),
      error: error instanceof Error ? error.message : 'Unknown error',
      database: 'disconnected',
    };

    return NextResponse.json(errorStatus, { status: 503 });
  }
}
