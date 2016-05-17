#${PMpre} EDG::WP4::CCM::Path${PMpost}

use parent qw(Exporter);
our @EXPORT    = qw(unescape);
our @EXPORT_OK = qw(escape);

use LC::Exception qw(SUCCESS throw_error);

our $ec = LC::Exception::Context->new->will_store_errors;

use overload '""' => 'toString';

=head1 NAME

EDG::WP4::CCM::Path - Path class

=head1 SYNOPSIS

    $path = EDG::WP4::CCM::Path->new("/hardware/memory/size");
    print "$path"; # stringification

    $path = $path->down($level);

    $path = $path->up();

=head1 DESCRIPTION

Module provides implementation of the Path class. Class is used
to manipulate absolute paths

=head2 Public methods

=over

=item new ($path)

Create new C<EDG::WP4::CCM::Path> instance.

If C<path> argument is not specified, root path (C</>) is used.
Empty string is not allowed as an argument.

C<path> is a string representation of the path as defined in the NVA-API
Specification document.

=cut

sub new
{
    my ($class, $path) = @_;
    unless (defined($path)) {
        $path = "/";
    }

    my @s = path_split($path);
    my $start = shift @s;

    # remove trailing /
    my $end = pop @s;
    push(@s, $end) if (defined($end) && $end ne '');

    # must start with /, but not with //+
    unless (defined($start) && $start eq '' && (!@s || $s[0] ne '')) {
        throw_error("path $path must be an absolute path: start '"
                    . ($start || '')
                    . "', remainder "
                    . join(' / ', @s));
        return ();
    }

    my $self = \@s;
    bless($self, $class);
    return $self;
}

=item toString

Get the string representation of path. The C<EDG::WP4::CCM::Path>
instances also support stringification (this C<toString> also is used
for that).

=cut

sub toString
{
    my ($self) = @_;
    return "/" . join('/', @$self);
}

=item up

Removes last chunk of the path and returns it.
If the path is already C</> then the method
raises an exception.

=cut

sub up
{
    my ($self) = @_;
    
    if (@$self == 0) {
        throw_error("could not go up, it will generate empty path");
        return ();
    }
    return pop(@$self);
}

=item down

Add one chunk to the path. The chunk cannot be compound path
(it cannot contain "/" or be empty).

=cut

sub down
{
    my ($self, $chunk) = @_;

    my @chunks = path_split($chunk);

    # This check is not needed, should be safe to add all chunks
    if (scalar @chunks != 1) {
        throw_error("input is not a simple path chunk");
        return ();
    }
    push(@$self, @chunks);
    return $self;
}

=item merge

Return a new instance with optional (list of) subpaths added.

=cut


sub merge
{

    my ($self, @subpaths) = @_;

    my $newpath = EDG::WP4::CCM::Path->new("$self");
    foreach my $subpath (@subpaths) {
        $newpath->down($subpath);
    }
    return $newpath
}

=back

=head2 Public functions

=over

=item unescape

Returns an unescaped version of the argument. This method is exported
for use with all the components that deal with escaped keys.

=cut

sub unescape
{
    my $str = shift;
    $str =~ s!(_[0-9a-f]{2})!sprintf ("%c", hex($1))!eg;
    return $str;
}

=item escape

Returns an escaped version of the argument.  This method is exported on
demand for use with all tools that have to escape and unescape values.

=cut

sub escape
{
    my $str = shift;

    $str =~ s/(^[0-9]|[^a-zA-Z0-9])/sprintf("_%lx", ord($1))/eg;
    return $str;
}

=item path_split

Function to split a string in list of subpaths.
Supports escaping of subpaths wrapped in C<{...}>.

=cut

sub path_split
{
    my $path = shift;

    # First handle escape {} string
    # use -1, make sure no trailing empty strings are removed
    # Use postive lookahead, not a match for trailing /|$
    my @to_esc = split(/(\/|^)\{(.+?)\}(?=(?:\/|$))/, $path, -1);
    # Handle empty string path
    # Splitting an empty string always returns an empty list
    push(@to_esc, '') if ! @to_esc;

    # This is an array with odd number of elements <val>[<sep><val>[<sep><val>[...]]]
    # <sep> is the matching group of the split pattern
    # Shift first element (initial <val>)
    my $esc_path = shift(@to_esc);

    while (@to_esc) {
        # First 2 are the matched groups that make up <sep>
        #   The second group must be escaped
        # 3rd is the <val>
        $esc_path .= join('', shift(@to_esc), escape(shift(@to_esc)), shift(@to_esc));
    }

    return split('/', $esc_path, -1);
}

=pod

=back

=cut

1;
