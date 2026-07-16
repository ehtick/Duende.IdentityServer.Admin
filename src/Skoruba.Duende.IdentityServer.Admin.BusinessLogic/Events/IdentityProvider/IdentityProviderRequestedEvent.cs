using Skoruba.AuditLogging.Events;
using Skoruba.Duende.IdentityServer.Admin.BusinessLogic.Dtos.IdentityProvider;
using Skoruba.Duende.IdentityServer.Admin.BusinessLogic.Helpers;

namespace Skoruba.Duende.IdentityServer.Admin.BusinessLogic.Events.IdentityProvider
{
    public class IdentityProviderRequestedEvent : AuditEvent
    {
        public IdentityProviderDto IdentityProvider { get; set; }

        public IdentityProviderRequestedEvent(IdentityProviderDto identityProvider)
        {
            IdentityProvider = AuditEventDataSanitizer.Sanitize(identityProvider);
        }
    }
}
