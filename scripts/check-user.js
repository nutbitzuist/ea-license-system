const { PrismaClient } = require('@prisma/client');

async function findUser() {
    const p = new PrismaClient();
    try {
        const u = await p.user.findUnique({ where: { email: 'email.nutty@gmail.com' } });
        console.log('User found:', u ? { id: u.id, email: u.email, role: u.role, isActive: u.isActive, isApproved: u.isApproved } : 'NOT FOUND');
    } finally {
        await p.$disconnect();
    }
}

findUser();
