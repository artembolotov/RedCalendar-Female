//
//  ConsentMiddleware.swift
//  RedCalendar-Female
//

import Foundation

/// Consent to the processing of personal data (SYNC.md §21): read the current version, accept it.
///
/// It owns the `consent` domain, so the inner switch is exhaustive. Both requests run in their own
/// `Task` — they wait on the network, and the store's effect queue is serial.
let consentMiddleware: Middleware = { state, action, dispatch in
    @Injected var apiService: APIServiceProtocol

    guard case .consent(let consentAction) = action else { return }

    switch consentAction {

    case .fetchCurrent:
        Task {
            do {
                let response = try await apiService.fetchConsentVersion()

                guard response.success, let data = response.data else {
                    throw APIServiceError.serverError(response.message ?? "Consent version unavailable")
                }

                dispatch(.consent(.currentFetched(version: data.version)))

            } catch {
                AppLogger.error("Consent version request failed", error: error)
                dispatch(.consent(.currentFetchFailed(error.localizedDescription)))
            }
        }

    case .accept(let version):
        // The reducer has already shown the request as in flight; only an answer takes that back,
        // so a missing session is answered rather than ignored — same as `devicesMiddleware`.
        guard let deviceId = state.deviceId else {
            AppLogger.warn("Consent acceptance asked for without a session")
            dispatch(.consent(.acceptFailed("No session")))
            return
        }

        Task {
            do {
                let response = try await apiService.acceptConsent(deviceId: deviceId, version: version)

                guard response.success, let data = response.data else {
                    throw APIServiceError.serverError(response.message ?? "Consent acceptance failed")
                }

                dispatch(.consent(.accepted(version: data.version)))
                // `consent_required` comes back down only with a run.
                dispatch(.sync(.requested(.consentAccepted)))

            } catch {
                if let refusal = ConsentRefusal(error) {
                    // An outdated version is the person's to answer; an invalid one is ours.
                    if case .invalid = refusal {
                        AppLogger.error("Consent version \(version) refused as invalid", error: error)
                    } else {
                        AppLogger.info("Consent version \(version) is outdated")
                    }
                    dispatch(.consent(.acceptRefused(refusal)))
                } else {
                    AppLogger.error("Consent acceptance failed", error: error)
                    dispatch(.consent(.acceptFailed(error.localizedDescription)))
                }
            }
        }

    // Answers: the reducer's, not this one's. Spelled out rather than swept into a `default`, so a
    // new case here is a build error in this file.
    case .setRequired, .currentFetched, .currentFetchFailed, .accepted, .acceptRefused, .acceptFailed:
        break

    // The sign-in step's bookkeeping. The requests that carry the version belong to
    // `authMiddleware` and `migrationMiddleware`.
    case .agreeForSignIn, .signInConsentOutdated, .discardSignInConsent:
        break
    }
}
