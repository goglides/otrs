# --
# Copyright (C) 2001-2018 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# get selenium object
my $Selenium = $Kernel::OM->Get('Kernel::System::UnitTest::Selenium');

$Selenium->RunTest(
    sub {

        # get helper object
        my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

        # create test customer user
        my $TestCustomerUserLogin = $Helper->TestCustomerUserCreate(
        ) || die "Did not get test customer user";

        # get ticket object
        my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

        # create test ticket
        my $TicketNumber = $TicketObject->TicketCreateNumber();
        my $TicketID     = $TicketObject->TicketCreate(
            TN           => $TicketNumber,
            Title        => 'Some Ticket Title',
            Queue        => 'Raw',
            Lock         => 'unlock',
            Priority     => '3 normal',
            State        => 'new',
            CustomerID   => $TestCustomerUserLogin,
            CustomerUser => $TestCustomerUserLogin,
            OwnerID      => 1,
            UserID       => 1,
        );
        $Self->True(
            $TicketID,
            "Ticket is created - $TicketID",
        );

        # Create test email article, invisible for customer.
        my $InvisibleBody = 'invisible body';
        my $ArticleID     = $TicketObject->ArticleCreate(
            TicketID       => $TicketID,
            ArticleType    => 'email-internal',
            SenderType     => 'agent',
            Subject        => 'an article subject',
            Body           => $InvisibleBody,
            Charset        => 'ISO-8859-15',
            MimeType       => 'text/plain',
            HistoryType    => 'EmailCustomer',
            HistoryComment => 'Some free text!',
            UserID         => 1,
        );
        $Self->True(
            $ArticleID,
            "ArticleCreate - ID $ArticleID",
        );

        # login test customer user
        $Selenium->Login(
            Type     => 'Customer',
            User     => $TestCustomerUserLogin,
            Password => $TestCustomerUserLogin,
        );

        # search for new created ticket on CustomerTicketOverview screen (default filter is Open)
        $Self->True(
            $Selenium->find_element("//a[contains(\@href, \'Action=CustomerTicketZoom;TicketNumber=$TicketNumber' )]"),
            "Ticket with ticket number $TicketNumber is found on screen with Open filter"
        );

        # Make sure the article body is not displayed (internal article).
        $Self->True(
            index( $Selenium->get_page_source(), $InvisibleBody ) == -1,
            'Article body is not visible to customer',
        );

        # check All filter on CustomerTicketOverview screen
        $Selenium->find_element(
            "//a[contains(\@href, \'Action=CustomerTicketOverview;Subaction=MyTickets;Filter=All' )]"
        )->VerifiedClick();

        $Self->True(
            $Selenium->find_element("//a[contains(\@href, \'Action=CustomerTicketZoom;TicketNumber=$TicketNumber' )]"),
            "Ticket with ticket number $TicketNumber is found on screen with All filter"
        );

        # check Close filter on CustomerTicketOverview screen
        # there is only one created ticket, and it should not be on screen with Close filter
        $Selenium->find_element(
            "//a[contains(\@href, \'Action=CustomerTicketOverview;Subaction=MyTickets;Filter=Close' )]"
        )->VerifiedClick();

        $Self->True(
            index( $Selenium->get_page_source(), "Action=CustomerTicketZoom;TicketNumber=$TicketNumber" ) == -1,
            "Ticket with ticket number $TicketNumber is not found on screen with Close filter"
        );

        # clean up test data from the DB
        my $Success = $TicketObject->TicketDelete(
            TicketID => $TicketID,
            UserID   => 1,
        );
        $Self->True(
            $Success,
            "Ticket with ticket number $TicketNumber is deleted"
        );

        # make sure the cache is correct
        $Kernel::OM->Get('Kernel::System::Cache')->CleanUp( Type => 'Ticket' );

    }
);

1;
