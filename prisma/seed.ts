import { PrismaClient } from "@prisma/client"
import { hash } from "bcryptjs"

const prisma = new PrismaClient()

async function main() {
  console.log("Seeding database...")

  // Create admin user
  const adminPassword = await hash("admin123", 12)
  const admin = await prisma.user.upsert({
    where: { email: "admin@example.com" },
    update: {},
    create: {
      email: "admin@example.com",
      name: "Admin User",
      passwordHash: adminPassword,
      role: "ADMIN",
      isApproved: true,
      isActive: true,
      subscriptionTier: "TIER_3",
    },
  })
  console.log("Created admin user:", admin.email)

  // Create sample EAs
  const sampleEAs = [
    {
      eaCode: "scalper_pro_v1",
      name: "Scalper Pro",
      description: "Professional scalping EA for high-frequency trading",
      currentVersion: "1.0.0",
    },
    {
      eaCode: "trend_master_v2",
      name: "Trend Master",
      description: "Trend-following EA with advanced risk management",
      currentVersion: "2.1.0",
    },
    {
      eaCode: "grid_trader_v1",
      name: "Grid Trader",
      description: "Grid trading EA for ranging markets",
      currentVersion: "1.5.0",
    },
  ]

  for (const ea of sampleEAs) {
    const created = await prisma.expertAdvisor.upsert({
      where: { eaCode: ea.eaCode },
      update: {},
      create: ea,
    })
    console.log("Created EA:", created.name)
  }

  // Grant admin access to all EAs
  const allEAs = await prisma.expertAdvisor.findMany()
  for (const ea of allEAs) {
    await prisma.userEaAccess.upsert({
      where: {
        userId_eaId: {
          userId: admin.id,
          eaId: ea.id,
        },
      },
      update: {},
      create: {
        userId: admin.id,
        eaId: ea.id,
      },
    })
  }
  console.log("Granted admin access to all EAs")

  console.log("Seeding completed!")
}

main()
  .catch((e) => {
    console.error(e)
    process.exit(1)
  })
  .finally(async () => {
    await prisma.$disconnect()
  })
