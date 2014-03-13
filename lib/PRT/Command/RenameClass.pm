package PRT::Command::RenameClass;
use strict;
use warnings;
use PPI;
use Path::Class;

sub new {
    my ($class) = @_;
    bless {
        rule => undef,
    }, $class;
}

# register a replacing rule
# arguments:
#   $source: source class name
#   $dest:   destination class name
sub register {
    my ($self, $source_class_name, $destination_class_name) = @_;

    $self->{source_class_name} = $source_class_name;
    $self->{destination_class_name} = $destination_class_name;
}

sub source_class_name {
    my ($self) = @_;

    $self->{source_class_name};
}

sub destination_class_name {
    my ($self) = @_;

    $self->{destination_class_name};
}

# refactor a file
# argumensts:
#   $file: filename for refactoring
# todo:
#   - support package block syntax
#   - multi packages in one file
sub execute {
    my ($self, $file) = @_;

    my $replaced = 0;

    my $document = PPI::Document->new($file);

    my $package_statement_renamed = $self->_try_rename_package_statement($document);

    $replaced += $self->_try_rename_includes($document);

    $replaced += $self->_try_rename_tokens($document);

    if ($package_statement_renamed) {
        $document->save($self->_destination_file($file));
        unlink($file);
    } else {
        return unless $replaced;
        $document->save($file);
    }
}

sub _try_rename_package_statement {
    my ($self, $document) = @_;

    my $package = $document->find_first('PPI::Statement::Package');

    return unless $package;
    return unless $package->namespace eq $self->source_class_name;

    my $namespace = $package->schild(1);

    return unless $namespace->isa('PPI::Token::Word');

    $namespace->set_content($self->destination_class_name);
    1;
}

sub _try_rename_includes {
    my ($self, $document) = @_;

    my $replaced = 0;

    for my $statement (@{ $document->find('PPI::Statement::Include') }) {
        next unless defined $statement->module;
        next unless $statement->module eq $self->source_class_name;

        my $module = $statement->schild(1);

        return unless $module->isa('PPI::Token::Word');

        $module->set_content($self->destination_class_name);
        $replaced++;
    }

    $replaced;
}

# discussions:
#   seems too wild
sub _try_rename_tokens {
    my ($self, $document) = @_;

    my $replaced = 0;

    for my $token (@{ $document->find('PPI::Token') }) {
        next unless $token->content eq $self->source_class_name;
        $token->set_content($self->destination_class_name);
        $replaced++;
    }

    $replaced;
}

sub _destination_file {
    my ($self, $file) = @_;

    my @source_dirs = split '::', $self->source_class_name;
    pop @source_dirs;

    my @destination_dirs = split '::', $self->destination_class_name;
    my ($destination_basename) = pop @destination_dirs;

    my $dir = file($file)->dir;

    $dir = $dir->parent for @source_dirs;

    $dir = $dir->subdir(@destination_dirs);
    $dir->file("$destination_basename.pm").q();
}

1;