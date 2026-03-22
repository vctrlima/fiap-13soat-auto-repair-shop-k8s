const crypto = require("crypto");

/**
 * API Gateway v2 Lambda Authorizer (payload format 2.0)
 * Verifies HS256 JWT tokens for protected API routes.
 * Uses native Node.js crypto — no external dependencies.
 */

function base64UrlDecode(str) {
  str = str.replace(/-/g, "+").replace(/_/g, "/");
  while (str.length % 4) str += "=";
  return Buffer.from(str, "base64");
}

function verifyHS256(token, secret) {
  const parts = token.split(".");
  if (parts.length !== 3) return null;

  const [headerB64, payloadB64, signatureB64] = parts;
  const signature = base64UrlDecode(signatureB64);
  const expected = crypto
    .createHmac("sha256", secret)
    .update(`${headerB64}.${payloadB64}`)
    .digest();

  if (signature.length !== expected.length) return null;
  if (!crypto.timingSafeEqual(signature, expected)) return null;

  const payload = JSON.parse(base64UrlDecode(payloadB64).toString("utf8"));

  if (payload.exp && payload.exp < Math.floor(Date.now() / 1000)) return null;
  if (payload.iss !== "https://auto-repair-shop.auth") return null;
  if (payload.aud !== "auto-repair-shop-api") return null;

  return payload;
}

exports.handler = async (event) => {
  const token = (event.headers?.authorization || "").replace(/^Bearer\s+/i, "");

  if (!token) {
    return { isAuthorized: false };
  }

  try {
    const payload = verifyHS256(token, process.env.JWT_ACCESS_TOKEN_SECRET);

    if (!payload) {
      return { isAuthorized: false };
    }

    return {
      isAuthorized: true,
      context: {
        userId: payload.sub || payload.id || "unknown",
        tokenType: payload.type || "user",
      },
    };
  } catch (err) {
    return { isAuthorized: false };
  }
};
