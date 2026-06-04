// Copyright (c) Jan Škoruba. All Rights Reserved.
// Licensed under the Apache License, Version 2.0.

using System.Text.Json;
using Skoruba.Duende.IdentityServer.Admin.BusinessLogic.Dtos.Configuration;
using Skoruba.Duende.IdentityServer.Admin.BusinessLogic.Dtos.Grant;
using Skoruba.Duende.IdentityServer.Admin.BusinessLogic.Dtos.IdentityProvider;

namespace Skoruba.Duende.IdentityServer.Admin.BusinessLogic.Helpers
{
    public static class AuditEventDataSanitizer
    {
        private static readonly JsonSerializerOptions CloneOptions = new()
        {
            PropertyNameCaseInsensitive = false
        };

        public static ClientDto Sanitize(ClientDto client)
        {
            var sanitizedClient = Clone(client);
            if (sanitizedClient?.ClientSecrets == null)
            {
                return sanitizedClient;
            }

            foreach (var secret in sanitizedClient.ClientSecrets)
            {
                if (secret != null)
                {
                    secret.Value = null;
                }
            }

            return sanitizedClient;
        }

        public static ClientSecretsDto Sanitize(ClientSecretsDto clientSecrets)
        {
            var sanitizedClientSecrets = Clone(clientSecrets);
            if (sanitizedClientSecrets == null)
            {
                return null;
            }

            sanitizedClientSecrets.Value = null;

            if (sanitizedClientSecrets.ClientSecrets == null)
            {
                return sanitizedClientSecrets;
            }

            foreach (var secret in sanitizedClientSecrets.ClientSecrets)
            {
                if (secret != null)
                {
                    secret.Value = null;
                }
            }

            return sanitizedClientSecrets;
        }

        public static PersistedGrantDto Sanitize(PersistedGrantDto persistedGrant)
        {
            var sanitizedGrant = Clone(persistedGrant);
            if (sanitizedGrant == null)
            {
                return null;
            }

            sanitizedGrant.Data = null;
            sanitizedGrant.SessionId = null;
            return sanitizedGrant;
        }

        public static PersistedGrantsDto Sanitize(PersistedGrantsDto persistedGrants)
        {
            var sanitizedGrants = Clone(persistedGrants);
            if (sanitizedGrants?.PersistedGrants == null)
            {
                return sanitizedGrants;
            }

            foreach (var persistedGrant in sanitizedGrants.PersistedGrants)
            {
                if (persistedGrant != null)
                {
                    persistedGrant.Data = null;
                    persistedGrant.SessionId = null;
                }
            }

            return sanitizedGrants;
        }

        public static IdentityProviderDto Sanitize(IdentityProviderDto identityProvider)
        {
            var sanitizedIdentityProvider = Clone(identityProvider);
            if (sanitizedIdentityProvider?.Properties == null)
            {
                return sanitizedIdentityProvider;
            }

            foreach (var property in sanitizedIdentityProvider.Properties.Values)
            {
                if (property != null)
                {
                    property.Value = null;
                }
            }

            return sanitizedIdentityProvider;
        }

        public static ApiSecretsDto Sanitize(ApiSecretsDto apiSecrets)
        {
            var sanitizedApiSecrets = Clone(apiSecrets);
            if (sanitizedApiSecrets == null)
            {
                return null;
            }

            sanitizedApiSecrets.Value = null;

            if (sanitizedApiSecrets.ApiSecrets == null)
            {
                return sanitizedApiSecrets;
            }

            foreach (var secret in sanitizedApiSecrets.ApiSecrets)
            {
                if (secret != null)
                {
                    secret.Value = null;
                }
            }

            return sanitizedApiSecrets;
        }

        public static IdentityProvidersDto Sanitize(IdentityProvidersDto identityProviders)
        {
            var sanitizedIdentityProviders = Clone(identityProviders);
            if (sanitizedIdentityProviders?.IdentityProviders == null)
            {
                return sanitizedIdentityProviders;
            }

            foreach (var identityProvider in sanitizedIdentityProviders.IdentityProviders)
            {
                if (identityProvider?.Properties == null)
                {
                    continue;
                }

                foreach (var property in identityProvider.Properties.Values)
                {
                    if (property != null)
                    {
                        property.Value = null;
                    }
                }
            }

            return sanitizedIdentityProviders;
        }

        private static T Clone<T>(T source)
        {
            if (source == null)
            {
                return default;
            }

            var serialized = JsonSerializer.Serialize(source, CloneOptions);
            return JsonSerializer.Deserialize<T>(serialized, CloneOptions);
        }
    }
}
