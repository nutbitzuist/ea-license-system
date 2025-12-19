import { PrismaClient } from "@prisma/client"
import { hash } from "bcryptjs"

const prisma = new PrismaClient()

async function createAdmin() {
    const email = "email.nutty@gmail.com"
    const password = "Admin123!" // You can change this after first login
    const name = "Admin"

    console.log(`Creating admin user: ${email}...`)

    // Hash the password
    const passwordHash = await hash(password, 12)

    // Create or update the user
    const user = await prisma.user.upsert({
        where: { email },
        create: {
            email,
            passwordHash,
            name,
            role: "ADMIN",
            isApproved: true,
            isActive: true,
            subscriptionTier: "TIER_3",
        },
        update: {
            role: "ADMIN",
            isApproved: true,
            isActive: true,
            subscriptionTier: "TIER_3",
        },
    })

    console.log("✅ Admin user created/updated!")
    console.log("   Email:", user.email)
    console.log("   Password: Admin123!")
    console.log("   Role:", user.role)
    console.log("   Is Approved:", user.isApproved)
    console.log("   Is Active:", user.isActive)

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

    console.log("\n🎉 Done! You can now login with:")
    console.log(`   Email: ${email}`)
    console.log(`   Password: Admin123!`)
    console.log(`\n⚠️  Please change your password after logging in!`)
}

createAdmin()
    .catch((e) => {
        console.error("Error:", e)
        process.exit(1)
    })
    .finally(async () => {
        await prisma.$disconnect()
    })
