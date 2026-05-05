const YOCO_SECRET_KEY = "sk_test_8b22aead6mMQK1E598840429cc02";

async function testYoco() {
  const response = await fetch("https://payments.yoco.com/api/checkouts", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${YOCO_SECRET_KEY}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      amount: 29900,
      currency: "ZAR",
      metadata: {
        vendorId: "test",
        planId: "test"
      }
    })
  });
  const text = await response.text();
  console.log("Status:", response.status);
  console.log("Response:", text);
}
testYoco();
