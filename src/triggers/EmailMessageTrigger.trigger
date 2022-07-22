trigger EmailMessageTrigger on EmailMessage (after insert) {
    try {
        EmailMessageTriggerHandler.createCaseTeamMember(Trigger.new);
    } catch (Exception e) {
        System.debug(e);
    }
}