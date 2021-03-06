//
//  StatusMenuPresenter.swift
//  WhatsNext
//
//  Created by Nicholas Bellucci on 11/5/18.
//  Copyright © 2018 Nicholas Bellucci. All rights reserved.
//

import Foundation
import EventKit

class StatusMenuPresenter: UpdateHandling {
    let eventStore = EKEventStore()
    var calendars = [EKCalendar]()

    var updateHandler: UpdateHandler?

    var eventViewModel: EventViewModel? {
        guard let event = event else { return nil }
        return EventViewModel(title: event.title, date: event.startDate)
    }

    var currentEvent: EKEvent? {
        return event
    }

    var eventStartDate: Date? {
        guard let event = event else { return nil }
        return event.startDate
    }

    var eventEndDate: Date? {
        guard let event = event else { return nil }
        return event.endDate
    }

    private var timer: Timer?

    private var event: EKEvent? {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        guard let end = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) else { return nil }
        let eventsPredicate = eventStore.predicateForEvents(withStart: Date(), end: end, calendars: calendars)
        let events = eventStore.events(matching: eventsPredicate).sorted { $0.startDate < $1.startDate }
        return events.first(where: { event -> Bool in
            event.isAllDay == false
        })
    }

    required init() {}
}

extension StatusMenuPresenter {
    func load() {
        checkPermission { [weak self] error in
            guard let sself = self else { return }
            sself.calendars = EKEventStore().calendars(for: EKEntityType.event)
            sself.updateHandler?(error)

            if sself.timer == nil {
                sself.timer = Timer(timeInterval: 60.0, target: sself, selector: #selector(sself.refreshCalendar(_:)), userInfo: nil, repeats: true)
            }
        }
    }
}

private extension StatusMenuPresenter {
    func checkPermission(completion: @escaping (Error?) -> ()) {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .authorized:
            completion(nil)
        case .notDetermined:
            eventStore.requestAccess(to: .event) { allowed, error in
                if let error = error {
                    completion(error)
                } else {
                    if allowed {
                        completion(nil)
                    } else {
                        completion(CalendarError.notAllowed)
                    }
                }
            }
        case .restricted, .denied:
            completion(CalendarError.denied)
        }
    }

    @objc
    func refreshCalendar(_ timer: Timer) {
        eventStore.refreshSourcesIfNecessary()
    }
}
