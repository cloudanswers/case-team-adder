trigger EmailMessageTrigger on EmailMessage (after insert) {
    EmailMessageTriggerHandler.createCaseTeamMemberSafe(Trigger.new);
}