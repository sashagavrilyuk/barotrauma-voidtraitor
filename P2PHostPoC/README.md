# Barotrauma automatic P2P host PoC

This is a minimal proof of concept for Barotrauma/LuaCsForBarotrauma 1.13.4.0.

It does not replace Steam/EOS networking. The patch only adds `-autop2phost`, which calls the existing in-game Host Server path after loading is complete. The existing `P2POwnerPeer`, Steam/EOS sockets, `ChildServerRelay` and `DedicatedServer` P2P path remain unchanged.

## Test

1. Back up the Barotrauma installation directory.
2. Configure the server once through the normal Host Server menu so `serversettings.xml` contains a non-empty server name and the desired public/max-player/password settings.
3. Copy the Windows build artifact over the matching Barotrauma 1.13.4.0 installation.
4. Start Barotrauma with:

   `-autop2phost -skipintro`

5. The client should log:

   `Starting server automatically using P2P networking...`

6. The child dedicated server must log:

   `Using P2P networking.`

   If it logs `Using Lidgren networking.`, the PoC failed and the test result is invalid.

7. Test from a client that normally fails to join the direct-UDP dedicated server, with VPN/Zapret disabled. Verify server visibility, lobby/submarine sync, chat, voice and round sync.

## Scope

The PoC intentionally keeps the graphical owner client alive. It proves only that an automatically launched dedicated server can use the same Steam/EOS P2P transport as the normal Host Server flow. Removing the GUI/owner client is a separate next step after this test succeeds.
