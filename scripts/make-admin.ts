import { PrismaClient } from "@prisma/client"

const prisma = new PrismaClient()

async function makeAdmin() {
  const email = "email.nutty@gmail.com"
  
  console.log(`Making ${email} an admin...`)
  
  // Update the user to be admin, approved, and active
  const user = await prisma.user.update({
    where: { email },
    data: {
      role: "ADMIN",
      isApproved: true,
      isActive: true,
      subscriptionTier: "TIER_3",
    },
  })
  
  console.log("Updated user:", user.email)
  console.log("Role:", user.role)
  console.log("Is Approved:", user.isApproved)
  console.log("Is Active:", user.isActive)
  
  // Grant access to all EAs
  const allEAs = await prisma.expertAdvisor.findMany()
  console.log(`\nGranting access to ${allEAs.length} EAs...`)
  
  for (const ea of allEAs) {
    await prisma.userEaAccess.upsert({
      where: {
        userId_eaId: {
          userId: user.id,
          eaId: ea.id,
        },
      },
      update: {},
      create: {
        userId: user.id,
        eaId: ea.id,
      },
    })
    console.log(`  - Granted access to: ${ea.name}`)
  }
  
  console.log("\nDone! You can now login with:", email)
}

makeAdmin()
  .catch((e) => {
    console.error("Error:", e)
    process.exit(1)
  })
  .finally(async () => {
    await prisma.$disconnect()
  })
