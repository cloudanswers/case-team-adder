trigger EmailMessageTrigger on EmailMessage (after insert) {
    EmailMessageTriggerHandler.createCaseTeamMember(Trigger.new);
}